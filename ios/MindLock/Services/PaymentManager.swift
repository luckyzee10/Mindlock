import Foundation
import OSLog
import StoreKit

@MainActor
final class PaymentManager: ObservableObject {
    enum SubscriptionStatus: Equatable {
        case unknown
        case notSubscribed
        case subscribed(expiration: Date?)
    }

    enum PurchaseState: Equatable {
        case idle
        case loadingProducts
        case purchasing
        case validating
        case pending
        case failed(String)
    }

    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown

    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "PaymentManager")
    private let apiClient: APIClient
    private let userIdentity: UserIdentity
    private var transactionListenerTask: Task<Void, Never>?
    private let subscriptionProductIds: [String] = ["mindlock.plus.monthly", "mindlock.plus.annual"]

    init(apiClient: APIClient = .shared, userIdentity: UserIdentity = .shared) {
        self.apiClient = apiClient
        self.userIdentity = userIdentity
        transactionListenerTask = listenForTransactions()
        Task { await refreshSubscriptionStatus() }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    var isProcessing: Bool {
        switch purchaseState {
        case .purchasing, .validating:
            return true
        default:
            return false
        }
    }

    var primaryProduct: Product? {
        availableProducts.sorted(by: { $0.price < $1.price }).first
    }

    func loadProductsIfNeeded() async {
        guard availableProducts.isEmpty else { return }
        purchaseState = .loadingProducts
        logger.info("🔄 Loading MindLock+ products")
        do {
            let products = try await Product.products(for: subscriptionProductIds)
            if products.isEmpty {
                logger.error("❌ StoreKit returned 0 products for MindLock+")
                throw PaymentError.productUnavailable
            }
            availableProducts = products
            logger.info("✅ Loaded \(products.count) MindLock+ product(s)")
            purchaseState = .idle
        } catch {
            logger.error("❌ Failed to load product: \(error.localizedDescription, privacy: .public)")
            purchaseState = .failed(error.userFacingMessage)
        }
    }

    func purchaseSubscription() async throws {
        guard let product = primaryProduct else {
            throw PaymentError.productUnavailable
        }

        purchaseState = .purchasing
        logger.info("🛒 Attempting MindLock+ purchase")
        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            logger.info("✅ Purchase succeeded, verifying transaction…")
            let transaction = try checkVerified(verificationResult)
            guard let expiration = activeExpiration(for: transaction) else {
                await transaction.finish()
                SharedSettings.updateSubscriptionStatus(activeUntil: nil)
                SharedSettings.updateSubscriptionTier(productId: nil)
                subscriptionStatus = .notSubscribed
                purchaseState = .failed(PaymentError.noActiveEntitlement.userFacingMessage)
                throw PaymentError.noActiveEntitlement
            }

            SharedSettings.updateSubscriptionStatus(activeUntil: expiration)
            SharedSettings.updateSubscriptionTier(productId: transaction.productID)
            subscriptionStatus = .subscribed(expiration: expiration)
            purchaseState = .validating
            let receiptData = loadReceiptDataIfAvailable()
            let transactionJWS = verificationResult.jwsRepresentation
            let submission = PurchaseSubmissionRequest(
                userId: userIdentity.userId,
                userEmail: userIdentity.email,
                charityId: "exercise-unlocks",
                charityName: "Exercise Unlocks",
                productId: transaction.productID,
                transactionId: String(transaction.id),
                transactionJWS: transactionJWS,
                receiptData: receiptData,
                subscriptionTier: transaction.productID
            )
            do {
                logger.info("📨 Submitting receipt to backend for transaction \(transaction.id, privacy: .public)")
                _ = try await apiClient.submitPurchase(submission)
                logger.info("✅ Backend receipt submission completed")
            } catch {
                logger.error("⚠️ Backend receipt submission failed after Apple purchase: \(error.localizedDescription, privacy: .public)")
            }
            await transaction.finish()
            await refreshSubscriptionStatus()
            logger.info("🏁 Purchase flow completed successfully")
            purchaseState = .idle

        case .pending:
            logger.info("⌛️ Purchase pending user action")
            purchaseState = .pending
            throw PaymentError.pending

        case .userCancelled:
            logger.info("🙅‍♂️ User cancelled purchase")
            purchaseState = .idle
            throw PaymentError.userCancelled

        @unknown default:
            logger.error("❌ Purchase hit unknown StoreKit result")
            purchaseState = .failed(PaymentError.unknown.userFacingMessage)
            throw PaymentError.unknown
        }
    }

    func refreshSubscriptionStatus() async {
        var latestExpiration: Date?
        var latestProductId: String?
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard subscriptionProductIds.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard let expiration = activeExpiration(for: transaction, referenceDate: now) else { continue }

            if let latest = latestExpiration {
                if expiration > latest {
                    latestExpiration = expiration
                    latestProductId = transaction.productID
                }
            } else {
                latestExpiration = expiration
                latestProductId = transaction.productID
            }
        }

        await MainActor.run {
            if let latestExpiration {
                subscriptionStatus = .subscribed(expiration: latestExpiration)
                SharedSettings.updateSubscriptionStatus(activeUntil: latestExpiration)
                SharedSettings.updateSubscriptionTier(productId: latestProductId)
            } else {
                SharedSettings.updateSubscriptionStatus(activeUntil: nil)
                subscriptionStatus = .notSubscribed
                SharedSettings.updateSubscriptionTier(productId: nil)
            }
        }
    }

    private func activeExpiration(for transaction: Transaction, referenceDate: Date = Date()) -> Date? {
        guard transaction.revocationDate == nil else { return nil }
        guard let expiration = transaction.expirationDate else { return nil }
        return expiration > referenceDate ? expiration : nil
    }

    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw PaymentError.failedVerification(error.localizedDescription)
        }
    }

    private func loadReceiptDataIfAvailable() -> String? {
        guard let url = Bundle.main.appStoreReceiptURL else {
            logger.info("🧾 No receipt URL available; proceeding without receipt data")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            logger.info("🧾 Receipt found locally (\(data.count) bytes)")
            return data.base64EncodedString()
        } catch {
            logger.info("🧾 Receipt not readable; continuing with transaction JWS only")
            return nil
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if self.subscriptionProductIds.contains(transaction.productID) {
                        await self.refreshSubscriptionStatus()
                    }
                }
            }
        }
    }
}

enum PaymentError: LocalizedError {
    case productUnavailable
    case userCancelled
    case pending
    case failedVerification(String)
    case missingReceipt
    case noActiveEntitlement
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "We couldn’t load MindLock+. Check your App Store connection and try again."
        case .userCancelled:
            return "Purchase cancelled."
        case .pending:
            return "Your purchase is pending approval. Try again once it’s complete."
        case .failedVerification(let reason):
            return "Apple couldn’t verify this purchase: \(reason)"
        case .missingReceipt:
            return "We couldn’t read the App Store receipt. Make sure you’re signed in to the App Store and try again."
        case .noActiveEntitlement:
            return "Apple did not return an active MindLock+ subscription entitlement. Please try again or restore purchases."
        case .unknown:
            return "Something unexpected happened with your purchase."
        }
    }
}

private extension Error {
    var userFacingMessage: String {
        if let error = self as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return localizedDescription
    }
}
