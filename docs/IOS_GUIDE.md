# MindLock iOS Development Guide 📱

## Overview

Complete guide for developing the MindLock iOS app using SwiftUI, Screen Time APIs, and StoreKit 2.

---

## Project Setup

### 1. Xcode Project Creation

```bash
# Open Xcode and create new project
# Choose iOS > App
# Product Name: MindLock
# Interface: SwiftUI
# Language: Swift
# Minimum iOS: 16.0
```

### 2. Project Configuration

#### Info.plist Settings
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>MindLock needs access to Screen Time to help you manage app usage limits and build healthier digital habits.</string>

<key>NSDeviceActivityUsageDescription</key>
<string>MindLock monitors your app usage to enforce daily limits and provide insights into your digital wellness.</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>mindlock-auth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>mindlock</string>
        </array>
    </dict>
</array>
```

#### Package Dependencies (Swift Package Manager)
```swift
// In Package.swift or Xcode > File > Add Package Dependencies

dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.18.0"),
    .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
    .package(url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
    .package(url: "https://github.com/airbnb/lottie-ios", from: "4.4.0")
]

targets: [
    .target(
        name: "MindLock",
        dependencies: [
            .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            .product(name: "Alamofire", package: "Alamofire"),
            .product(name: "KeychainSwift", package: "keychain-swift"),
            .product(name: "Lottie", package: "lottie-ios")
        ]
    )
]
```

### 3. Capabilities & Entitlements

#### Xcode Project Settings
1. **Signing & Capabilities**
   - Add "Family Controls" capability
   - Add "In-App Purchase" capability
   - Configure App Groups (optional for extensions)

#### Entitlements File
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.family-controls</key>
    <true/>
    <key>com.apple.developer.deviceactivity</key>
    <true/>
</dict>
</plist>
```

---

## App Structure

### Main App File
```swift
// MindLockApp.swift
import SwiftUI
import Firebase

@main
struct MindLockApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var screenTimeManager = ScreenTimeManager()
    @StateObject private var paymentManager = PaymentManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(screenTimeManager)
                .environmentObject(paymentManager)
        }
    }
}
```

### Root Content View
```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if screenTimeManager.isAuthorized {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            authService.checkAuthState()
        }
    }
}
```

---

## Screen Time Integration

### 1. Authorization Manager
```swift
// ScreenTimeManager.swift
import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

@MainActor
class ScreenTimeManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var dailyLimitMinutes: Int = 60
    @Published var isMonitoring = false
    
    private let center = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() async throws {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = true
            }
        } catch {
            throw ScreenTimeError.authorizationFailed
        }
    }
    
    private func checkAuthorizationStatus() {
        isAuthorized = center.authorizationStatus == .approved
    }
    
    func startMonitoring() throws {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        let activity = DeviceActivityName("MindLockDailyLimit")
        
        let events = [
            DeviceActivityEvent.Name("dailyLimitReached"): DeviceActivityEvent(
                applications: selectedApps.applicationTokens,
                threshold: DateComponents(minute: dailyLimitMinutes)
            )
        ]
        
        try deviceActivityCenter.startMonitoring(
            activity,
            during: schedule,
            events: events
        )
        
        isMonitoring = true
    }
    
    func stopMonitoring() {
        let activity = DeviceActivityName("MindLockDailyLimit")
        deviceActivityCenter.stopMonitoring([activity])
        isMonitoring = false
    }
    
    func blockApps() {
        store.application.blockedApplications = selectedApps.applicationTokens
        store.shield.applications = selectedApps.applicationTokens
    }
    
    func unblockApps() {
        store.application.blockedApplications = nil
        store.shield.applications = nil
    }
    
    func temporaryUnlock(for duration: TimeInterval) {
        unblockApps()
        
        // Re-block after specified duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.blockApps()
        }
    }
}

enum ScreenTimeError: Error {
    case authorizationFailed
    case notAuthorized
    case monitoringFailed
}
```

### 2. App Selection View
```swift
// AppSelectionView.swift
import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var isShowingPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Apps to Limit")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose the apps you want to limit during your focus time")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                isShowingPicker = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Select Apps")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            
            if !screenTimeManager.selectedApps.applicationTokens.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected Apps: \(screenTimeManager.selectedApps.applicationTokens.count)")
                        .font(.headline)
                    
                    // Display selected apps (simplified)
                    Text("Apps will be blocked when you reach your daily limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .familyActivityPicker(
            isPresented: $isShowingPicker,
            selection: $screenTimeManager.selectedApps
        )
    }
}
```

### 3. Time Limit Configuration
```swift
// LimitsConfigView.swift
import SwiftUI

struct LimitsConfigView: View {
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var tempLimit: Double
    
    init() {
        _tempLimit = State(initialValue: 60.0) // Default 1 hour
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Set Daily Limit")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 15) {
                Text("\(Int(tempLimit)) minutes")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Slider(
                    value: $tempLimit,
                    in: 15...240,
                    step: 15
                ) {
                    Text("Daily Limit")
                } minimumValueLabel: {
                    Text("15m")
                } maximumValueLabel: {
                    Text("4h")
                }
                .accentColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
            
            Button(action: {
                screenTimeManager.dailyLimitMinutes = Int(tempLimit)
                Task {
                    try screenTimeManager.startMonitoring()
                }
            }) {
                Text("Start Monitoring")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .disabled(screenTimeManager.selectedApps.applicationTokens.isEmpty)
            
            Spacer()
        }
        .padding()
        .onAppear {
            tempLimit = Double(screenTimeManager.dailyLimitMinutes)
        }
    }
}
```

---

## Payment Integration (StoreKit 2)

### 1. Payment Manager
```swift
// PaymentManager.swift
import StoreKit
import Foundation

@MainActor
class PaymentManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProducts: [Product] = []
    @Published var isLoading = false
    
    private let productIDs = [
        "mindlock.unlock.30min",
        "mindlock.unlock.1hour",
        "mindlock.unlock.2hour"
    ]
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Send to backend for validation
            await validatePurchaseWithBackend(transaction)
            
            await updatePurchases()
            await transaction.finish()
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            throw PaymentError.paymentPending
            
        @unknown default:
            throw PaymentError.unknown
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PaymentError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchases()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    private func updatePurchases() async {
        var purchasedProducts: [Product] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    purchasedProducts.append(product)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        self.purchasedProducts = purchasedProducts
    }
    
    private func validatePurchaseWithBackend(_ transaction: Transaction) async {
        // Implement backend validation
        guard let receiptData = await getReceiptData() else { return }
        
        let validationRequest = PurchaseValidationRequest(
            transactionId: String(transaction.id),
            productId: transaction.productID,
            receiptData: receiptData
        )
        
        do {
            let response = try await APIClient.shared.validatePurchase(validationRequest)
            if response.success {
                // Unlock apps for specified duration
                let unlockDuration = TimeInterval(response.unlockDurationMinutes * 60)
                ScreenTimeManager.shared.temporaryUnlock(for: unlockDuration)
            }
        } catch {
            print("Backend validation failed: \(error)")
        }
    }
    
    private func getReceiptData() async -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData.base64EncodedString()
    }
}

enum PaymentError: Error {
    case failedVerification
    case paymentPending
    case unknown
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
}
```

### 2. Unlock Prompt View
```swift
// UnlockPromptView.swift
import SwiftUI
import StoreKit

struct UnlockPromptView: View {
    @EnvironmentObject var paymentManager: PaymentManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 15) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Time's Up!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("You've reached your daily limit. Choose to unlock more time and support a good cause.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 15) {
                    ForEach(paymentManager.products, id: \.id) { product in
                        UnlockOptionView(
                            product: product,
                            isSelected: selectedProduct?.id == product.id
                        )
                        .onTapGesture {
                            selectedProduct = product
                        }
                    }
                }
                
                if let selectedProduct = selectedProduct {
                    Button(action: {
                        Task {
                            do {
                                try await paymentManager.purchase(selectedProduct)
                                dismiss()
                            } catch {
                                // Handle purchase error
                                print("Purchase failed: \(error)")
                            }
                        }
                    }) {
                        HStack {
                            if paymentManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Unlock & Donate")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(paymentManager.isLoading)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Unlock Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Later") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct UnlockOptionView: View {
    let product: Product
    let isSelected: Bool
    
    private var unlockDuration: String {
        switch product.id {
        case "mindlock.unlock.30min":
            return "30 minutes"
        case "mindlock.unlock.1hour":
            return "1 hour"
        case "mindlock.unlock.2hour":
            return "2 hours"
        default:
            return "Unknown"
        }
    }
    
    private var charityAmount: String {
        let price = product.price
        let charityDonation = price * 0.07 // ~10% of post-Apple revenue
        return "$\(String(format: "%.2f", charityDonation))"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(unlockDuration)
                    .font(.headline)
                
                Text("\(charityAmount) goes to charity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(product.displayPrice)
                .font(.title3)
                .fontWeight(.semibold)
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
```

---

## Authentication Service

### Firebase Authentication Integration
```swift
// AuthenticationService.swift
import Firebase
import Foundation
import Combine

@MainActor
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let firebaseUser = user {
                    self?.currentUser = User(from: firebaseUser)
                    await self?.syncWithBackend()
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }
    
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            currentUser = User(from: result.user)
        } catch {
            throw AuthenticationError.signInFailed
        }
    }
    
    func signInWithApple() async throws {
        // Implement Apple Sign In
        // This would use AuthenticationServices framework
        isLoading = true
        defer { isLoading = false }
        
        // Implementation details for Apple Sign In
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }
    
    func checkAuthState() {
        if let firebaseUser = Auth.auth().currentUser {
            currentUser = User(from: firebaseUser)
            isAuthenticated = true
        }
    }
    
    private func syncWithBackend() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        
        do {
            let idToken = try await firebaseUser.getIDToken()
            let response = try await APIClient.shared.authenticateUser(idToken: idToken)
            // Update user profile from backend
        } catch {
            print("Backend sync failed: \(error)")
        }
    }
}

enum AuthenticationError: Error {
    case signInFailed
    case tokenRefreshFailed
}

struct User: Codable {
    let id: String
    let email: String?
    let displayName: String?
    let isAnonymous: Bool
    
    init(from firebaseUser: Firebase.User) {
        self.id = firebaseUser.uid
        self.email = firebaseUser.email
        self.displayName = firebaseUser.displayName
        self.isAnonymous = firebaseUser.isAnonymous
    }
}
```

---

## API Client

### Network Service
```swift
// APIClient.swift
import Foundation
import Alamofire

class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "https://your-backend-url.com/api"
    private let session: Session
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = Session(configuration: configuration)
    }
    
    func authenticateUser(idToken: String) async throws -> AuthResponse {
        let url = "\(baseURL)/auth/firebase-login"
        
        let response = try await session.request(
            url,
            method: .post,
            headers: ["Authorization": "Bearer \(idToken)"]
        ).serializingDecodable(AuthResponse.self).value
        
        return response
    }
    
    func validatePurchase(_ request: PurchaseValidationRequest) async throws -> PurchaseValidationResponse {
        let url = "\(baseURL)/purchases/validate"
        
        let response = try await session.request(
            url,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: await getAuthHeaders()
        ).serializingDecodable(PurchaseValidationResponse.self).value
        
        return response
    }
    
    func getCharities() async throws -> CharitiesResponse {
        let url = "\(baseURL)/charities/list"
        
        let response = try await session.request(
            url,
            method: .get,
            headers: await getAuthHeaders()
        ).serializingDecodable(CharitiesResponse.self).value
        
        return response
    }
    
    private func getAuthHeaders() async -> HTTPHeaders {
        // Get stored JWT token
        let token = KeychainHelper.shared.getToken()
        return ["Authorization": "Bearer \(token ?? "")"]
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: BackendUser
}

struct BackendUser: Codable {
    let id: String
    let email: String
    let selectedCharityId: String?
}

struct CharitiesResponse: Codable {
    let charities: [Charity]
}

struct Charity: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let website: String?
    let logoUrl: String?
}
```

---

## Development Workflow

### 1. Testing on Device
```bash
# Always test on physical device for Screen Time APIs
# Screen Time APIs don't work in Simulator

# Required for testing:
# - iOS device with iOS 16.0+
# - Developer account
# - Proper provisioning profile with Family Controls capability
```

### 2. Debug Configuration
```swift
// Debug helpers for development
#if DEBUG
extension ScreenTimeManager {
    func mockBlockedState() {
        // Mock blocked state for UI testing
    }
    
    func resetMonitoring() {
        // Reset for testing
        stopMonitoring()
        UserDefaults.standard.removeObject(forKey: "selectedApps")
    }
}
#endif
```

### 3. Build Configurations
```swift
// Build-specific configurations
struct Config {
    static let baseURL: String = {
        #if DEBUG
        return "http://localhost:3000/api"
        #else
        return "https://your-production-url.com/api"
        #endif
    }()
    
    static let isTestFlight: Bool = {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }()
}
```

This iOS development guide provides the foundation for building the MindLock app with proper Screen Time integration, payment processing, and backend connectivity. 