# MindLock Tech Stack 🛠️

## Overview

Modern, scalable tech stack optimized for rapid iOS development with reliable backend infrastructure.

---

## iOS Frontend 📱

### Core Technologies
```
Language: Swift 5.9+
Framework: SwiftUI + UIKit hybrid
iOS Target: iOS 16.0+
Xcode: 15.0+
Architecture: MVVM with Combine
```

### Key Frameworks
```swift
// Screen Time & Device Management
import DeviceActivity      // Monitor app usage
import ManagedSettings     // Apply app restrictions  
import FamilyControls      // App authorization & selection

// Payments & Store
import StoreKit           // In-App Purchases (StoreKit 2)

// Backend & Auth
import FirebaseAuth       // User authentication
import FirebaseAnalytics  // Usage analytics

// UI & Navigation
import SwiftUI           // Primary UI framework
import UIKit             // Screen Time UI components
```

### Dependencies (SPM)
```swift
// Package.swift dependencies
.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.18.0"),
.package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
.package(url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
.package(url: "https://github.com/airbnb/lottie-ios", from: "4.4.0")
```

### Project Structure
```
MindLock.xcodeproj/
├── App/
│   ├── MindLockApp.swift              # App entry point
│   ├── ContentView.swift              # Root view
│   └── Config/
│       ├── Info.plist                 # App configuration
│       └── GoogleService-Info.plist   # Firebase config
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── PermissionsView.swift
│   │   └── OnboardingViewModel.swift
│   ├── ScreenTime/
│   │   ├── ScreenTimeManager.swift
│   │   ├── AppSelectionView.swift
│   │   ├── UsageDashboardView.swift
│   │   └── InterventionView.swift
│   ├── Payments/
│   │   ├── PaymentManager.swift
│   │   ├── UnlockPromptView.swift
│   │   ├── PurchaseFlowView.swift
│   │   └── PaymentModels.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── CharitySelectionView.swift
│   │   └── PurchaseHistoryView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       ├── LimitsConfigView.swift
│       └── NotificationSettings.swift
├── Services/
│   ├── APIClient.swift                # Backend communication
│   ├── AuthenticationService.swift    # User auth management
│   ├── AnalyticsService.swift         # Event tracking
│   └── NotificationService.swift      # Local notifications
├── Models/
│   ├── User.swift                     # User data model
│   ├── Purchase.swift                 # Purchase transaction
│   ├── Charity.swift                  # Charity information
│   ├── AppUsage.swift                 # Screen time data
│   └── TimeLimit.swift                # Usage limits
├── Utilities/
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── View+Extensions.swift
│   │   └── Color+Extensions.swift
│   ├── Constants.swift                # App constants
│   └── UserDefaultsKeys.swift         # Storage keys
└── Resources/
    ├── Assets.xcassets               # Images & colors
    ├── Localizable.strings           # Text localization
    └── Fonts/                        # Custom fonts
```

---

## Backend Infrastructure 🔧

### Core Stack
```javascript
Runtime: Node.js 18+
Framework: Express.js 4.18+
Database: PostgreSQL 15+
ORM: Prisma 5.0+
Authentication: Firebase Admin SDK
Hosting: Railway (primary) / Render (backup)
```

### Key Dependencies
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "prisma": "^5.6.0",
    "@prisma/client": "^5.6.0",
    "firebase-admin": "^11.11.1",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "winston": "^3.11.0",
    "joi": "^17.11.0",
    "bcrypt": "^5.1.1",
    "jsonwebtoken": "^9.0.2",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  }
}
```

### Project Structure
```
backend/
├── src/
│   ├── app.js                        # Express app setup
│   ├── server.js                     # Server entry point
│   ├── routes/
│   │   ├── auth.js                   # Authentication routes
│   │   ├── purchases.js              # Purchase handling
│   │   ├── charities.js              # Charity management
│   │   ├── users.js                  # User management
│   │   └── admin.js                  # Admin endpoints
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── purchaseController.js
│   │   ├── charityController.js
│   │   └── adminController.js
│   ├── services/
│   │   ├── firebaseService.js        # Firebase integration
│   │   ├── appleIAPService.js        # Apple receipt validation
│   │   ├── donationService.js        # Charity calculations
│   │   └── analyticsService.js       # Data analytics
│   ├── middleware/
│   │   ├── auth.js                   # JWT verification
│   │   ├── validation.js             # Input validation
│   │   ├── errorHandler.js           # Error management
│   │   └── rateLimit.js              # API rate limiting
│   ├── models/
│   │   └── schema.prisma             # Database schema
│   ├── utils/
│   │   ├── logger.js                 # Winston logging
│   │   ├── constants.js              # App constants
│   │   └── helpers.js                # Utility functions
│   └── config/
│       ├── database.js               # DB configuration
│       ├── firebase.js               # Firebase setup
│       └── environment.js            # Environment config
├── tests/
│   ├── auth.test.js
│   ├── purchases.test.js
│   └── donations.test.js
├── prisma/
│   ├── schema.prisma
│   └── migrations/
├── package.json
├── .env.example
└── README.md
```

---

## Database Schema 🗄️

### PostgreSQL with Prisma ORM

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id                String    @id @default(cuid())
  firebaseUid       String    @unique
  email             String    @unique
  displayName       String?
  selectedCharityId String?
  isActive          Boolean   @default(true)
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
  
  selectedCharity   Charity?  @relation(fields: [selectedCharityId], references: [id])
  purchases         Purchase[]
  
  @@map("users")
}

model Charity {
  id          String    @id @default(cuid())
  name        String    @unique
  description String
  website     String?
  logoUrl     String?
  isActive    Boolean   @default(true)
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  
  users           User[]
  purchases       Purchase[]
  monthlyReports  MonthlyReport[]
  
  @@map("charities")
}

model Purchase {
  id                     String    @id @default(cuid())
  userId                 String
  charityId              String
  productId              String
  amountCents            Int       // Amount in cents (USD)
  appleFeesCents         Int       // Apple's 30% cut
  charityDonationCents   Int       // 10% of post-Apple revenue
  platformRevenueCents   Int       // Remaining 90%
  appleTransactionId     String    @unique
  appleReceiptData       String?
  isValidated            Boolean   @default(false)
  unlockDurationMinutes  Int       // Time unlocked in minutes
  createdAt              DateTime  @default(now())
  processedAt            DateTime?
  
  user    User    @relation(fields: [userId], references: [id])
  charity Charity @relation(fields: [charityId], references: [id])
  
  @@map("purchases")
}

model MonthlyReport {
  id               String    @id @default(cuid())
  month            Int       // 1-12
  year             Int
  charityId        String
  totalAmountCents Int       // Total donations for this charity/month
  status           String    @default("pending") // pending, generated, paid
  generatedAt      DateTime  @default(now())
  paidAt           DateTime?
  
  charity Charity @relation(fields: [charityId], references: [id])
  
  @@unique([month, year, charityId])
  @@map("monthly_reports")
}

model AppConfig {
  id    String @id @default(cuid())
  key   String @unique
  value String
  
  @@map("app_config")
}
```

---

## Apple IAP Integration 💳

### StoreKit 2 Implementation

```swift
// PaymentManager.swift
import StoreKit

@MainActor
class PaymentManager: ObservableObject {
    private let productIDs = [
        "mindlock.unlock.30min",
        "mindlock.unlock.1hour", 
        "mindlock.unlock.2hour"
    ]
    
    @Published var products: [Product] = []
    @Published var purchasedProducts: [Product] = []
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchases()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
```

### Product Configuration
```
App Store Connect Products:

1. mindlock.unlock.30min
   - Type: Consumable
   - Price: $0.99 USD
   - Description: "Unlock 30 minutes of app time"

2. mindlock.unlock.1hour  
   - Type: Consumable
   - Price: $1.99 USD
   - Description: "Unlock 1 hour of app time"

3. mindlock.unlock.2hour
   - Type: Consumable
   - Price: $2.99 USD
   - Description: "Unlock 2 hours of app time"
```

---

## Screen Time Integration 📱

### Required Frameworks
```swift
import DeviceActivity
import ManagedSettings  
import FamilyControls
```

### Permission Flow
```swift
// 1. Request authorization
let center = AuthorizationCenter.shared
do {
    try await center.requestAuthorization(for: .individual)
} catch {
    // Handle authorization failure
}

// 2. Set up monitoring
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)

let activity = DeviceActivityName("SocialMediaLimit")
let center = DeviceActivityCenter()

try center.startMonitoring(
    activity,
    during: schedule,
    events: [
        DeviceActivityEvent.Name("LimitReached"): DeviceActivityEvent(
            applications: selectedApps,
            threshold: DateComponents(minute: dailyLimit)
        )
    ]
)
```

### App Restriction Implementation
```swift
// ManagedSettings to block apps
import ManagedSettings

let store = ManagedSettingsStore()

// Block specific applications
store.application.blockedApplications = selectedApplicationTokens

// Configure shield (intervention screen)
store.shield.applications = selectedApplicationTokens
store.shield.applicationCategories = ShieldActionExtension.self
```

---

## Admin Dashboard 📊

### React Tech Stack
```javascript
// Frontend
Framework: React 18
TypeScript: 5.0+
Styling: Tailwind CSS 3.3+
Charts: Chart.js / React Chart.js 2
State: Zustand (lightweight alternative to Redux)
Routing: React Router 6

// Build & Dev
Vite: 5.0+ (build tool)
ESLint: 8.0+ (linting)
Prettier: 3.0+ (formatting)
```

### Key Features
- Monthly donation reports and CSV export
- Real-time transaction monitoring  
- User analytics and engagement metrics
- Charity management interface
- Revenue tracking and forecasting

---

## Development Tools 🔨

### iOS Development
```
Xcode: 15.0+
iOS Simulator: iOS 16.0+
TestFlight: Beta distribution
Xcode Cloud: CI/CD (optional)
```

### Backend Development  
```
Node.js: 18+
npm/yarn: Package management
Prisma Studio: Database GUI
Railway CLI: Deployment
Postman: API testing
```

### General Tools
```
Git: Version control
GitHub: Repository hosting
Firebase Console: Auth & analytics management
App Store Connect: iOS app management
```

---

## Environment Configuration 🔧

### iOS (Info.plist)
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>MindLock needs access to Screen Time to help you manage app usage limits.</string>

<key>NSDeviceActivityUsageDescription</key>
<string>MindLock monitors your app usage to enforce daily limits and help improve productivity.</string>
```

### Backend (.env)
```bash
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/mindlock"

# Firebase
FIREBASE_PROJECT_ID="mindlock-app"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
FIREBASE_CLIENT_EMAIL="firebase-adminsdk@mindlock-app.iam.gserviceaccount.com"

# Apple
APPLE_SHARED_SECRET="your_shared_secret"
APPLE_TEAM_ID="your_team_id"

# App
JWT_SECRET="your_jwt_secret"
NODE_ENV="development"
PORT=3000
```

This tech stack provides a solid foundation for rapid development while maintaining scalability and security. Each component is chosen for reliability and ease of implementation. 