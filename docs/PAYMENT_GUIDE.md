# MindLock Payment Integration Guide 💳

## Overview

Complete guide for implementing Apple In-App Purchases using StoreKit 2, with backend validation and charity donation calculation.

> **Subscription update (Nov 2025).** MindLock now offers MindLock+ exclusively through two auto-renewable subscriptions:
>
> - `mindlock.plus.monthly` — $14.99 USD
> - `mindlock.plus.annual` — $143.99 USD
>
> Both tiers unlock the premium analytics, unlimited time blocks, and charity impact tracking. The free “Mindful Wait” unlock remains local-only with no StoreKit component. The rest of this guide documents the StoreKit wiring for these subscriptions.

---

## Apple In-App Purchase Setup

### 1. App Store Connect Configuration

#### Product Setup
```
Navigate to App Store Connect > My Apps > MindLock > Features > In-App Purchases

Create two Auto-Renewable Subscriptions in an appropriate subscription group:

1. mindlock.plus.monthly  
   - Reference Name: "MindLock+ Monthly"  
   - Product ID: `mindlock.plus.monthly`  
   - Price: $14.99 USD  
   - Description: "Monthly MindLock+ access with up to 20% donated to your charity."
2. mindlock.plus.annual  
   - Reference Name: "MindLock+ Annual"  
   - Product ID: `mindlock.plus.annual`  
   - Price: $143.99 USD  
   - Description: "Annual MindLock+ access with up to 20% donated to your charity."
```

#### Shared Secret Generation
```
1. Go to App Store Connect > My Apps > MindLock > App Information
2. Scroll down to "App-Specific Shared Secret"
3. Click "Generate" to create a shared secret
4. Save this secret for backend receipt validation
```

### 2. Xcode Project Configuration

#### Capabilities
```
1. Open Xcode project
2. Select target > Signing & Capabilities
3. Click "+ Capability"
4. Add "In-App Purchase"
5. Ensure proper provisioning profile is selected
```

#### Info.plist
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>buy.itunes.apple.com</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
        <key>sandbox.itunes.apple.com</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## iOS Implementation (StoreKit 2)

### 1. Product Manager

```swift
// PaymentManager.swift
import StoreKit
import Foundation

@MainActor
class PaymentManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseState: PurchaseState = .idle
    
    private let productIDs: Set<String> = ["mindlock.plus.monthly", "mindlock.plus.annual"]
    
    private var transactionListener: Task<Void, Error>?
    private var apiClient: APIClient
    
    enum PurchaseState {
        case idle
        case purchasing
        case validating
        case completed(UnlockResult)
        case failed(Error)
    }
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.transactionListener = listenForTransactions()
        
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { product1, product2 in
                product1.price < product2.price
            }
        } catch {
            print("Failed to load products: \(error)")
            purchaseState = .failed(PaymentError.productsNotLoaded)
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            await handlePurchaseResult(result)
        } catch {
            purchaseState = .failed(error)
        }
    }
    
    private func handlePurchaseResult(_ result: Product.PurchaseResult) async {
        switch result {
        case .success(let verification):
            await processPurchase(verification)
            
        case .userCancelled:
            purchaseState = .idle
            
        case .pending:
            purchaseState = .failed(PaymentError.paymentPending)
            
        @unknown default:
            purchaseState = .failed(PaymentError.unknown)
        }
    }
    
    private func processPurchase(_ verification: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(verification)
            
            // Validate with backend
            purchaseState = .validating
            let unlockResult = try await validateWithBackend(transaction)
            
            // Complete transaction
            await transaction.finish()
            purchaseState = .completed(unlockResult)
            
        } catch {
            purchaseState = .failed(error)
        }
    }
    
    // MARK: - Backend Validation
    
    private func validateWithBackend(_ transaction: Transaction) async throws -> UnlockResult {
        guard let receiptData = await getReceiptData() else {
            throw PaymentError.noReceipt
        }
        
        let request = PurchaseValidationRequest(
            transactionId: String(transaction.id),
            productId: transaction.productID,
            receiptData: receiptData
        )
        
        let response = try await apiClient.validatePurchase(request)
        
        return UnlockResult(
            unlockDurationMinutes: response.unlockDurationMinutes,
            charityDonationAmount: response.charityDonationAmount ?? 0
        )
    }
    
    private func getReceiptData() async -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return nil }
        
        do {
            let receiptData = try Data(contentsOf: receiptURL)
            return receiptData.base64EncodedString()
        } catch {
            print("Failed to read receipt: \(error)")
            return nil
        }
    }
    
    // MARK: - Transaction Monitoring
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                
                do {
                    let transaction = try self.checkVerified(result)
                    print("Transaction update: \(transaction.productID)")
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PaymentError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            print("Purchases restored successfully")
        } catch {
            purchaseState = .failed(error)
        }
    }
}

// MARK: - Supporting Types

enum PaymentError: LocalizedError {
    case productsNotLoaded
    case failedVerification
    case paymentPending
    case noReceipt
    case validationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productsNotLoaded:
            return "Could not load available products"
        case .failedVerification:
            return "Purchase verification failed"
        case .paymentPending:
            return "Payment is pending approval"
        case .noReceipt:
            return "No receipt data available"
        case .validationFailed:
            return "Purchase validation failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct UnlockResult {
    let unlockDurationMinutes: Int
    let charityDonationAmount: Double
}

struct PurchaseValidationRequest: Codable {
    let transactionId: String
    let productId: String
    let receiptData: String
}

struct PurchaseValidationResponse: Codable {
    let success: Bool
    let unlockDurationMinutes: Int
    let charityDonationAmount: Double?
    let error: String?
}
```

### 2. Purchase Flow UI

```swift
// UnlockPromptView.swift
import SwiftUI
import StoreKit

struct UnlockPromptView: View {
    @StateObject private var paymentManager = PaymentManager()
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                if paymentManager.isLoading {
                    loadingView
                } else {
                    productSelectionSection
                    
                    if selectedProduct != nil {
                        purchaseButton
                    }
                }
                
                charitySectionView
                
                Spacer()
            }
            .padding()
            .navigationTitle("Unlock Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Later") { dismiss() }
                }
            }
        }
        .onChange(of: paymentManager.purchaseState) { state in
            handlePurchaseStateChange(state)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Time's Up!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You've reached your daily limit. Choose to unlock more time and support a charity.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading unlock options...")
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
    }
    
    private var productSelectionSection: some View {
        VStack(spacing: 12) {
            Text("Choose unlock duration:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(paymentManager.products, id: \.id) { product in
                ProductOptionView(
                    product: product,
                    isSelected: selectedProduct?.id == product.id
                )
                .onTapGesture {
                    selectedProduct = product
                }
            }
        }
    }
    
    private var purchaseButton: some View {
        Button(action: purchaseSelectedProduct) {
            HStack {
                if case .purchasing = paymentManager.purchaseState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(purchaseButtonText)
            }
            .foregroundColor(.white)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(purchaseButtonColor)
            .cornerRadius(12)
        }
        .disabled(!canPurchase)
    }
    
    private var charitySectionView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("10% goes to charity")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text("Your selected charity will receive a portion of each unlock purchase")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Computed Properties
    
    private var purchaseButtonText: String {
        switch paymentManager.purchaseState {
        case .purchasing:
            return "Processing..."
        case .validating:
            return "Validating..."
        default:
            return "Unlock & Donate"
        }
    }
    
    private var purchaseButtonColor: Color {
        canPurchase ? .blue : .gray
    }
    
    private var canPurchase: Bool {
        selectedProduct != nil && 
        !paymentManager.isLoading &&
        paymentManager.purchaseState != .purchasing &&
        paymentManager.purchaseState != .validating
    }
    
    // MARK: - Actions
    
    private func purchaseSelectedProduct() {
        guard let product = selectedProduct else { return }
        
        Task {
            await paymentManager.purchase(product)
        }
    }
    
    private func handlePurchaseStateChange(_ state: PaymentManager.PurchaseState) {
        switch state {
        case .completed(let result):
            handleSuccessfulPurchase(result)
        case .failed(let error):
            handlePurchaseError(error)
        default:
            break
        }
    }
    
    private func handleSuccessfulPurchase(_ result: UnlockResult) {
        // Unlock apps for the purchased duration
        let unlockDuration = TimeInterval(result.unlockDurationMinutes * 60)
        screenTimeManager.temporaryUnlock(for: unlockDuration)
        
        // Show success feedback
        showSuccessAlert(result)
        
        // Dismiss the view
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            dismiss()
        }
    }
    
    private func handlePurchaseError(_ error: Error) {
        // Show error alert
        print("Purchase failed: \(error)")
        // Implement error alert here
    }
    
    private func showSuccessAlert(_ result: UnlockResult) {
        // Implement success alert showing unlock duration and charity donation
        print("Success! Unlocked \(result.unlockDurationMinutes) minutes, donated $\(result.charityDonationAmount)")
    }
}

struct ProductOptionView: View {
    let product: Product
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(productTitle)
                    .font(.headline)
                
                Text(charityDonationText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var productTitle: String {
        switch product.id {
        case "mindlock.unlock.30min":
            return "30 minutes"
        case "mindlock.unlock.1hour":
            return "1 hour"
        case "mindlock.unlock.2hour":
            return "2 hours"
        default:
            return "Unknown duration"
        }
    }
    
    private var charityDonationText: String {
        let charityAmount = product.price * 0.07 // ~10% of post-Apple revenue
        return "$\(String(format: "%.2f", charityAmount)) to charity"
    }
}
```

---

## Backend Validation

### 1. Apple Receipt Verification Service

```javascript
// src/services/appleIAPService.js
const https = require('https');
const crypto = require('crypto');
const logger = require('../utils/logger');

class AppleIAPService {
    constructor() {
        this.sandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
        this.productionUrl = 'https://buy.itunes.apple.com/verifyReceipt';
        this.sharedSecret = process.env.APPLE_SHARED_SECRET;
        
        // Product configuration
        this.products = {
            'mindlock.unlock.30min': {
                price: 99,     // $0.99 in cents
                duration: 30   // minutes
            },
            'mindlock.unlock.1hour': {
                price: 199,    // $1.99 in cents
                duration: 60   // minutes
            },
            'mindlock.unlock.2hour': {
                price: 299,    // $2.99 in cents
                duration: 120  // minutes
            }
        };
    }

    async verifyReceipt(receiptData, transactionId) {
        try {
            // Try production first
            let result = await this._makeVerificationRequest(this.productionUrl, receiptData);
            
            // Status 21007 means sandbox receipt sent to production
            if (result.status === 21007) {
                logger.info('Sandbox receipt detected, trying sandbox endpoint');
                result = await this._makeVerificationRequest(this.sandboxUrl, receiptData);
            }
            
            return this._processVerificationResult(result, transactionId);
        } catch (error) {
            logger.error('Apple receipt verification failed:', error);
            throw new Error('Receipt verification failed');
        }
    }

    async _makeVerificationRequest(url, receiptData) {
        return new Promise((resolve, reject) => {
            const postData = JSON.stringify({
                'receipt-data': receiptData,
                'password': this.sharedSecret,
                'exclude-old-transactions': true
            });

            const options = {
                hostname: new URL(url).hostname,
                path: new URL(url).pathname,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData)
                },
                timeout: 10000 // 10 second timeout
            };

            const req = https.request(options, (res) => {
                let data = '';
                
                res.on('data', (chunk) => {
                    data += chunk;
                });
                
                res.on('end', () => {
                    try {
                        const response = JSON.parse(data);
                        resolve(response);
                    } catch (parseError) {
                        reject(new Error('Invalid JSON response from Apple'));
                    }
                });
            });

            req.on('error', (error) => {
                reject(new Error(`Network error: ${error.message}`));
            });

            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Request timeout'));
            });

            req.write(postData);
            req.end();
        });
    }

    _processVerificationResult(result, transactionId) {
        // Check overall status
        if (result.status !== 0) {
            const errorMessage = this._getStatusErrorMessage(result.status);
            logger.error(`Apple verification failed with status ${result.status}: ${errorMessage}`);
            return {
                isValid: false,
                error: errorMessage,
                status: result.status
            };
        }

        // Find the specific transaction in the receipt
        const transaction = this._findTransactionInReceipt(result.receipt, transactionId);
        
        if (!transaction) {
            logger.error(`Transaction ${transactionId} not found in receipt`);
            return {
                isValid: false,
                error: 'Transaction not found in receipt'
            };
        }

        // Validate transaction details
        const validation = this._validateTransaction(transaction);
        
        if (!validation.isValid) {
            return validation;
        }

        // Return successful validation result
        return {
            isValid: true,
            transaction: {
                id: transaction.transaction_id,
                productId: transaction.product_id,
                purchaseDate: new Date(parseInt(transaction.purchase_date_ms)),
                quantity: parseInt(transaction.quantity),
                amount: this.products[transaction.product_id]?.price || 0,
                originalTransactionId: transaction.original_transaction_id
            },
            receipt: {
                bundleId: result.receipt.bundle_id,
                appVersion: result.receipt.application_version,
                originalAppVersion: result.receipt.original_application_version
            }
        };
    }

    _findTransactionInReceipt(receipt, transactionId) {
        const inAppPurchases = receipt.in_app || [];
        return inAppPurchases.find(purchase => 
            purchase.transaction_id === transactionId ||
            purchase.original_transaction_id === transactionId
        );
    }

    _validateTransaction(transaction) {
        // Check if product ID is valid
        if (!this.products[transaction.product_id]) {
            return {
                isValid: false,
                error: `Unknown product ID: ${transaction.product_id}`
            };
        }

        // Check quantity (should be 1 for consumables)
        if (parseInt(transaction.quantity) !== 1) {
            return {
                isValid: false,
                error: 'Invalid quantity for consumable product'
            };
        }

        // Check purchase date (not too old)
        const purchaseDate = new Date(parseInt(transaction.purchase_date_ms));
        const now = new Date();
        const hoursSincePurchase = (now - purchaseDate) / (1000 * 60 * 60);
        
        if (hoursSincePurchase > 24) {
            return {
                isValid: false,
                error: 'Transaction is too old'
            };
        }

        return { isValid: true };
    }

    _getStatusErrorMessage(status) {
        const statusMessages = {
            21000: 'The App Store could not read the JSON object you provided',
            21002: 'The data in the receipt-data property was malformed or missing',
            21003: 'The receipt could not be authenticated',
            21004: 'The shared secret you provided does not match the shared secret on file',
            21005: 'The receipt server is not currently available',
            21006: 'This receipt is valid but the subscription has expired',
            21007: 'This receipt is from the sandbox but was sent to the production environment',
            21008: 'This receipt is from the production environment but was sent to the sandbox'
        };
        
        return statusMessages[status] || `Unknown status code: ${status}`;
    }

    getProductConfig(productId) {
        return this.products[productId] || null;
    }

    calculateRevenueSplit(amountCents) {
        // Apple takes 30%
        const appleFees = Math.round(amountCents * 0.30);
        const netRevenue = amountCents - appleFees;
        
        // 10% of net revenue to charity
        const charityDonation = Math.round(netRevenue * 0.10);
        const platformRevenue = netRevenue - charityDonation;
        
        return {
            totalAmount: amountCents,
            appleFees,
            netRevenue,
            charityDonation,
            platformRevenue
        };
    }
}

module.exports = new AppleIAPService();
```

### 2. Purchase Validation Controller

```javascript
// src/controllers/purchaseController.js
const { PrismaClient } = require('@prisma/client');
const appleIAPService = require('../services/appleIAPService');
const logger = require('../utils/logger');

const prisma = new PrismaClient();

class PurchaseController {
    async validatePurchase(req, res) {
        const { transactionId, receiptData, productId } = req.body;
        const userId = req.user.id;

        try {
            // Check if transaction already processed
            const existingPurchase = await this._findExistingPurchase(transactionId);
            if (existingPurchase) {
                return this._respondWithExistingPurchase(res, existingPurchase);
            }

            // Verify receipt with Apple
            const verification = await appleIAPService.verifyReceipt(receiptData, transactionId);
            
            if (!verification.isValid) {
                logger.warn(`Invalid receipt for transaction ${transactionId}: ${verification.error}`);
                return res.status(400).json({
                    success: false,
                    error: verification.error || 'Invalid purchase receipt'
                });
            }

            // Validate product ID matches
            if (verification.transaction.productId !== productId) {
                logger.warn(`Product ID mismatch: expected ${productId}, got ${verification.transaction.productId}`);
                return res.status(400).json({
                    success: false,
                    error: 'Product ID mismatch'
                });
            }

            // Get user with selected charity
            const user = await this._getUserWithCharity(userId);
            if (!user.selectedCharity) {
                return res.status(400).json({
                    success: false,
                    error: 'No charity selected. Please select a charity first.'
                });
            }

            // Calculate revenue split
            const revenueSplit = appleIAPService.calculateRevenueSplit(verification.transaction.amount);
            const productConfig = appleIAPService.getProductConfig(productId);

            // Create purchase record
            const purchase = await this._createPurchaseRecord({
                userId,
                charityId: user.selectedCharityId,
                transactionId,
                productId,
                receiptData,
                verification,
                revenueSplit,
                unlockDuration: productConfig.duration
            });

            logger.info(`Purchase validated successfully: ${purchase.id} for user ${userId}`);

            // Return success response
            res.json({
                success: true,
                unlockDurationMinutes: purchase.unlockDurationMinutes,
                charityDonationAmount: purchase.charityDonationCents / 100,
                purchaseId: purchase.id
            });

        } catch (error) {
            logger.error('Purchase validation error:', error);
            res.status(500).json({
                success: false,
                error: 'Purchase validation failed. Please try again.'
            });
        }
    }

    async _findExistingPurchase(transactionId) {
        return await prisma.purchase.findUnique({
            where: { appleTransactionId: transactionId },
            include: { charity: true }
        });
    }

    _respondWithExistingPurchase(res, purchase) {
        logger.info(`Returning existing purchase: ${purchase.id}`);
        return res.json({
            success: true,
            unlockDurationMinutes: purchase.unlockDurationMinutes,
            charityDonationAmount: purchase.charityDonationCents / 100,
            purchaseId: purchase.id,
            note: 'Purchase already processed'
        });
    }

    async _getUserWithCharity(userId) {
        const user = await prisma.user.findUnique({
            where: { id: userId },
            include: { selectedCharity: true }
        });

        if (!user) {
            throw new Error('User not found');
        }

        return user;
    }

    async _createPurchaseRecord({
        userId,
        charityId,
        transactionId,
        productId,
        receiptData,
        verification,
        revenueSplit,
        unlockDuration
    }) {
        return await prisma.purchase.create({
            data: {
                userId,
                charityId,
                productId,
                amountCents: revenueSplit.totalAmount,
                appleFeesCents: revenueSplit.appleFees,
                netRevenueCents: revenueSplit.netRevenue,
                charityDonationCents: revenueSplit.charityDonation,
                platformRevenueCents: revenueSplit.platformRevenue,
                appleTransactionId: transactionId,
                appleReceiptData: receiptData,
                isValidated: true,
                unlockDurationMinutes: unlockDuration,
                processedAt: new Date()
            },
            include: { charity: true }
        });
    }

    // Additional methods for purchase history, stats, etc.
    async getPurchaseHistory(req, res) {
        try {
            const userId = req.user.id;
            const page = Math.max(1, parseInt(req.query.page) || 1);
            const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
            const skip = (page - 1) * limit;

            const [purchases, total] = await Promise.all([
                prisma.purchase.findMany({
                    where: { userId },
                    include: { charity: { select: { name: true, logoUrl: true } } },
                    orderBy: { createdAt: 'desc' },
                    skip,
                    take: limit
                }),
                prisma.purchase.count({ where: { userId } })
            ]);

            const formattedPurchases = purchases.map(purchase => ({
                id: purchase.id,
                productId: purchase.productId,
                amount: purchase.amountCents / 100,
                charityDonation: purchase.charityDonationCents / 100,
                unlockDurationMinutes: purchase.unlockDurationMinutes,
                charity: purchase.charity,
                createdAt: purchase.createdAt
            }));

            res.json({
                purchases: formattedPurchases,
                pagination: {
                    page,
                    limit,
                    total,
                    totalPages: Math.ceil(total / limit)
                }
            });

        } catch (error) {
            logger.error('Get purchase history error:', error);
            res.status(500).json({ error: 'Failed to get purchase history' });
        }
    }
}

module.exports = new PurchaseController();
```

---

## Testing & Validation

### 1. Sandbox Testing

```javascript
// Test configuration for sandbox environment
const testConfig = {
    // Use sandbox endpoints for testing
    appleVerificationUrl: 'https://sandbox.itunes.apple.com/verifyReceipt',
    
    // Test product IDs (same as production)
    testProducts: [
        'mindlock.unlock.30min',
        'mindlock.unlock.1hour',
        'mindlock.unlock.2hour'
    ],
    
    // Test user accounts
    sandboxTestUsers: [
        'sandbox_user1@example.com',
        'sandbox_user2@example.com'
    ]
};

// Test receipt validation
async function testReceiptValidation() {
    const testReceipt = 'base64_encoded_test_receipt';
    const testTransactionId = 'test_transaction_123';
    
    try {
        const result = await appleIAPService.verifyReceipt(testReceipt, testTransactionId);
        console.log('Test validation result:', result);
    } catch (error) {
        console.error('Test validation failed:', error);
    }
}
```

### 2. Error Handling

```swift
// iOS error handling for purchase flow
extension PaymentManager {
    func handlePurchaseError(_ error: Error) {
        DispatchQueue.main.async {
            switch error {
            case StoreKitError.userCancelled:
                // User cancelled - no action needed
                break
                
            case StoreKitError.networkError:
                self.showError("Network error. Please check your connection and try again.")
                
            case StoreKitError.systemError:
                self.showError("A system error occurred. Please try again later.")
                
            case PaymentError.validationFailed:
                self.showError("Purchase validation failed. Please contact support.")
                
            default:
                self.showError("An unexpected error occurred. Please try again.")
            }
        }
    }
    
    private func showError(_ message: String) {
        // Implement error display logic
        print("Payment Error: \(message)")
    }
}
```

---

## Security Considerations

### 1. Receipt Validation Security

```javascript
// Enhanced security measures
class SecureAppleIAPService extends AppleIAPService {
    constructor() {
        super();
        this.rateLimiter = new Map(); // Simple rate limiting
    }

    async verifyReceipt(receiptData, transactionId, userIP) {
        // Rate limiting
        if (!this.checkRateLimit(userIP)) {
            throw new Error('Too many verification requests');
        }

        // Validate receipt format
        if (!this.isValidReceiptFormat(receiptData)) {
            throw new Error('Invalid receipt format');
        }

        // Additional security checks
        const result = await super.verifyReceipt(receiptData, transactionId);
        
        if (result.isValid) {
            // Log successful validation for audit
            logger.info(`Successful purchase validation: ${transactionId} from IP: ${userIP}`);
        }

        return result;
    }

    checkRateLimit(userIP) {
        const now = Date.now();
        const userRequests = this.rateLimiter.get(userIP) || { count: 0, resetTime: now + 60000 };
        
        if (now > userRequests.resetTime) {
            userRequests.count = 0;
            userRequests.resetTime = now + 60000;
        }
        
        userRequests.count++;
        this.rateLimiter.set(userIP, userRequests);
        
        return userRequests.count <= 10; // Max 10 requests per minute
    }

    isValidReceiptFormat(receiptData) {
        try {
            // Check if it's valid base64
            const decoded = Buffer.from(receiptData, 'base64');
            return decoded.length > 0;
        } catch {
            return false;
        }
    }
}
```

### 2. Anti-Fraud Measures

```javascript
// Fraud detection
class FraudDetectionService {
    static async checkPurchase(userId, transactionId, amount) {
        // Check for duplicate transactions
        const recentDuplicates = await prisma.purchase.count({
            where: {
                userId,
                amountCents: amount,
                createdAt: {
                    gte: new Date(Date.now() - 5 * 60 * 1000) // Last 5 minutes
                }
            }
        });

        if (recentDuplicates > 2) {
            throw new Error('Suspicious activity detected');
        }

        // Check user purchase frequency
        const dailyPurchases = await prisma.purchase.count({
            where: {
                userId,
                createdAt: {
                    gte: new Date(Date.now() - 24 * 60 * 60 * 1000) // Last 24 hours
                }
            }
        });

        if (dailyPurchases > 20) {
            throw new Error('Daily purchase limit exceeded');
        }

        return true;
    }
}
```

This payment integration guide provides a complete implementation of Apple In-App Purchases with proper security measures, backend validation, and error handling for the MindLock app. 
