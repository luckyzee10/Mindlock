import Foundation
import OSLog
import StoreKit

@MainActor
final class PaymentManager: ObservableObject {
    enum PurchaseState: Equatable {
        case idle
        case loadingProducts
        case purchasing
        case validating
        case pending
        case failed(String)
    }

    @Published private(set) var availableProduct: Product?
    @Published private(set) var purchaseState: PurchaseState = .idle

    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "PaymentManager")
    private let apiClient: APIClient
    private let userIdentity: UserIdentity
    private var transactionListenerTask: Task<Void, Never>?

    init(apiClient: APIClient = .shared, userIdentity: UserIdentity = .shared) {
        self.apiClient = apiClient
        self.userIdentity = userIdentity
        transactionListenerTask = listenForTransactions()
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

    func loadProductIfNeeded() async {
        guard availableProduct == nil else { return }
        purchaseState = .loadingProducts
        logger.info("🔄 Loading products for day pass purchase")
        do {
            let products = try await Product.products(for: ["mindlock.daypass"])
            guard let product = products.first else {
                logger.error("❌ StoreKit returned 0 products for mindlock.daypass")
                throw PaymentError.productUnavailable
            }
            availableProduct = product
            logger.info("✅ Loaded product \(product.id, privacy: .public)")
            purchaseState = .idle
        } catch {
            logger.error("❌ Failed to load product: \(error.localizedDescription, privacy: .public)")
            purchaseState = .failed(error.userFacingMessage)
        }
    }

    func purchaseDayPass(for charity: Charity) async throws {
        guard let product = availableProduct else {
            throw PaymentError.productUnavailable
        }

        purchaseState = .purchasing
        logger.info("🛒 Attempting purchase for charity \(charity.id, privacy: .public)")
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
                receiptData: receiptData
            )
            do {
                logger.info("📨 Submitting receipt to backend for transaction \(transaction.id, privacy: .public)")
                _ = try await apiClient.submitPurchase(submission)
                await transaction.finish()
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
            return "We couldn’t load the MindLock Day Pass. Check your App Store connection and try again."
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
