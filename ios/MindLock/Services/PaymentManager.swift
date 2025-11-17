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

    func purchaseSubscription(for charity: Charity) async throws {
        guard let product = primaryProduct else {
            throw PaymentError.productUnavailable
        }

        purchaseState = .purchasing
        logger.info("🛒 Attempting MindLock+ purchase for charity \(charity.id, privacy: .public)")
        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            logger.info("✅ Purchase succeeded, verifying transaction…")
            let transaction = try checkVerified(verificationResult)
            purchaseState = .validating
            let receiptData = loadReceiptDataIfAvailable()
            let transactionJWS = verificationResult.jwsRepresentation
            let submission = PurchaseSubmissionRequest(
                userId: userIdentity.userId,
                userEmail: userIdentity.email,
                charityId: charity.id,
                charityName: charity.name,
                productId: transaction.productID,
                transactionId: String(transaction.id),
                transactionJWS: transactionJWS,
                receiptData: receiptData,
                subscriptionTier: transaction.productID
            )
            do {
                logger.info("📨 Submitting receipt to backend for transaction \(transaction.id, privacy: .public)")
                _ = try await apiClient.submitPurchase(submission)
                await transaction.finish()
                SharedSettings.updateSubscriptionTier(productId: transaction.productID)
                await refreshSubscriptionStatus()
                logger.info("🏁 Purchase flow completed successfully")
                purchaseState = .idle
            } catch {
                logger.error("❌ Backend validation failed: \(error.localizedDescription, privacy: .public)")
                purchaseState = .failed(error.userFacingMessage)
                throw error
            }

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
        var hasNonExpiringEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard subscriptionProductIds.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if latestProductId == nil || (transaction.expirationDate ?? .distantFuture) > (latestExpiration ?? .distantPast) {
                latestProductId = transaction.productID
            }
            if let expiration = transaction.expirationDate {
                if let latest = latestExpiration {
                    if expiration > latest {
                        latestExpiration = expiration
                    }
                } else {
                    latestExpiration = expiration
                }
            } else {
                hasNonExpiringEntitlement = true
            }
        }

        await MainActor.run {
            if hasNonExpiringEntitlement {
                subscriptionStatus = .subscribed(expiration: nil)
                SharedSettings.updateSubscriptionStatus(activeUntil: nil, isNonExpiring: true)
                SharedSettings.updateSubscriptionTier(productId: latestProductId)
            } else if let latestExpiration {
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
