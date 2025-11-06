# MindLock System Architecture 🏗️

## Overview

MindLock follows a client-server architecture with iOS app as the primary interface, Node.js backend for business logic, and PostgreSQL for data persistence. The system integrates with Apple's Screen Time APIs and payment processing.

---

## High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│                 │    │                  │    │                 │
│   iOS App       │◄──►│   Backend API    │◄──►│   PostgreSQL    │
│   (SwiftUI)     │    │   (Node.js)      │    │   Database      │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       
         │                       │                       
         ▼                       ▼                       
┌─────────────────┐    ┌──────────────────┐              
│                 │    │                  │              
│  Apple Services │    │  Admin Dashboard │              
│  • Screen Time  │    │    (React)       │              
│  • StoreKit     │    │                  │              
│  • App Store    │    │                  │              
└─────────────────┘    └──────────────────┘              
```

---

## Data Flow Diagrams

### 1. User Onboarding & Setup Flow

```
┌─────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  User   │───►│   Request   │───►│  Configure  │───►│    Start    │
│ Opens   │    │ Screen Time │    │ App Limits  │    │ Monitoring  │
│  App    │    │Permissions  │    │& Select Apps│    │             │
└─────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                       │                   │                   │
                       ▼                   ▼                   ▼
                ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                │   Apple     │    │   Local     │    │DeviceActivity│
                │Authorization│    │  Storage    │    │  Monitoring │
                │   Center    │    │             │    │             │
                └─────────────┘    └─────────────┘    └─────────────┘
```

### 2. Daily Usage & Blocking Flow

```
┌─────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  User   │───►│   Track     │───►│   Limit     │───►│   Block     │
│  Uses   │    │ App Usage   │    │  Reached?   │    │    Apps     │
│  Apps   │    │             │    │             │    │             │
└─────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                       │                   │                   │
                       ▼                   ▼                   ▼
                ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                │DeviceActivity│    │  Threshold  │    │ManagedSettings│
                │  Monitoring │    │    Event    │    │   Shield    │
                │             │    │             │    │             │
                └─────────────┘    └─────────────┘    └─────────────┘
```

### 3. Payment & Unlock Flow

```
┌─────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  User   │───►│   Show      │───►│  Process    │───►│   Unlock    │
│ Hits    │    │  Payment    │    │  Payment    │    │    Apps     │
│ Limit   │    │   Prompt    │    │             │    │             │
└─────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                       │                   │                   │
                       ▼                   ▼                   ▼
                ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                │   StoreKit  │    │   Backend   │    │   Remove    │
                │     IAP     │    │ Validation  │    │ Restrictions│
                │             │    │             │    │             │
                └─────────────┘    └─────────────┘    └─────────────┘
                                          │
                                          ▼
                                   ┌─────────────┐
                                   │   Update    │
                                   │  Database   │
                                   │ (Purchase + │
                                   │  Charity)   │
                                   └─────────────┘
```

### 4. Monthly Donation Reporting Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Scheduled  │───►│  Aggregate  │───►│  Generate   │───►│   Export    │
│   Cron Job  │    │ Purchases   │    │   Reports   │    │   to CSV    │
│             │    │   by Month  │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                   │                   │
                           ▼                   ▼                   ▼
                    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                    │  Calculate  │    │   Store     │    │    Admin    │
                    │ 10% for Each│    │   Monthly   │    │  Dashboard  │
                    │   Charity   │    │   Report    │    │   Access    │
                    └─────────────┘    └─────────────┘    └─────────────┘
```

---

## Component Architecture

### iOS App Architecture (MVVM)

```
┌─────────────────────────────────────────────────────────────────┐
│                           Views (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────┤
│ OnboardingView │ DashboardView │ PaymentView │ SettingsView    │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ViewModels                              │
├─────────────────────────────────────────────────────────────────┤
│ OnboardingVM   │ DashboardVM   │ PaymentVM   │ SettingsVM      │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Services                               │
├─────────────────────────────────────────────────────────────────┤
│ ScreenTimeManager │ PaymentManager │ APIClient │ AuthService    │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                           Models                                │
├─────────────────────────────────────────────────────────────────┤
│ User │ Purchase │ Charity │ AppUsage │ TimeLimit                │
└─────────────────────────────────────────────────────────────────┘
```

### Backend API Architecture (MVC)

```
┌─────────────────────────────────────────────────────────────────┐
│                           Routes                                │
├─────────────────────────────────────────────────────────────────┤
│ /auth │ /purchases │ /charities │ /users │ /admin               │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Controllers                              │
├─────────────────────────────────────────────────────────────────┤
│ AuthController │ PurchaseController │ CharityController │...    │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Services                               │
├─────────────────────────────────────────────────────────────────┤
│ FirebaseService │ AppleIAPService │ DonationService │...        │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Database (Prisma)                         │
├─────────────────────────────────────────────────────────────────┤
│ Users │ Purchases │ Charities │ MonthlyReports │ AppConfig      │
└─────────────────────────────────────────────────────────────────┘
```

---

## API Design

### Authentication

```
POST /auth/firebase-login
Headers: 
  Authorization: Bearer <firebase-id-token>
Response: 
  { token: "jwt-token", user: {...} }

GET /auth/user-profile
Headers: 
  Authorization: Bearer <jwt-token>
Response: 
  { user: {...}, selectedCharity: {...} }
```

### Purchase Management

```
POST /purchases/validate
Headers: 
  Authorization: Bearer <jwt-token>
Body: 
  { 
    transactionId: "apple-transaction-id",
    receiptData: "base64-encoded-receipt",
    productId: "mindlock.unlock.1hour"
  }
Response: 
  { 
    success: true, 
    unlockDurationMinutes: 60,
    charityDonationAmount: 0.14 
  }

GET /purchases/history
Headers: 
  Authorization: Bearer <jwt-token>
Query: 
  ?page=1&limit=10
Response: 
  { 
    purchases: [...],
    pagination: { page: 1, totalPages: 5, total: 50 }
  }
```

### Charity Management

```
GET /charities/list
Response: 
  { 
    charities: [
      { id: "1", name: "Charity A", description: "...", logoUrl: "..." },
      ...
    ]
  }

PUT /charities/select
Headers: 
  Authorization: Bearer <jwt-token>
Body: 
  { charityId: "charity-id" }
Response: 
  { success: true, selectedCharity: {...} }
```

### Admin Endpoints

```
GET /admin/monthly-reports
Headers: 
  Authorization: Bearer <admin-jwt-token>
Query: 
  ?month=11&year=2024
Response: 
  { 
    reports: [
      { 
        charityId: "1", 
        charityName: "Charity A",
        totalAmount: 150.75,
        transactionCount: 23,
        status: "generated"
      },
      ...
    ]
  }

POST /admin/generate-report
Headers: 
  Authorization: Bearer <admin-jwt-token>
Body: 
  { month: 11, year: 2024 }
Response: 
  { success: true, reportId: "report-id", csvUrl: "download-url" }
```

---

## Security Architecture

### Authentication Flow

1. **Firebase Authentication**: iOS app authenticates users with Firebase
2. **JWT Token Exchange**: Backend validates Firebase token and issues JWT
3. **API Authorization**: All protected endpoints require valid JWT
4. **Admin Access**: Separate admin JWT with elevated permissions

### Data Security

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS Keychain  │    │   HTTPS/TLS     │    │  PostgreSQL     │
│                 │───►│   Encryption    │───►│   Encryption    │
│ • JWT Tokens    │    │                 │    │                 │
│ • User Secrets  │    │ • API Traffic   │    │ • Data at Rest  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Payment Security

- **StoreKit 2**: Modern, secure payment processing
- **Receipt Validation**: Server-side validation with Apple
- **Transaction Verification**: Cryptographic verification of purchases
- **Audit Trail**: Complete logging of all financial transactions

---

## Screen Time Integration Architecture

### Permission Management

```swift
// 1. Request authorization during onboarding
AuthorizationCenter.shared.requestAuthorization(for: .individual)

// 2. App selection interface
FamilyActivityPicker() // Apple's built-in app selector

// 3. Store selected apps securely
UserDefaults.standard.set(selectedApps, forKey: "selectedApps")
```

### Monitoring Setup

```swift
// Configure monitoring schedule
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)

// Set up activity monitoring with threshold
let events = [
    DeviceActivityEvent.Name("dailyLimit"): DeviceActivityEvent(
        applications: selectedApplications,
        threshold: DateComponents(minute: dailyLimitMinutes)
    )
]

DeviceActivityCenter().startMonitoring(activity, during: schedule, events: events)
```

### Intervention & Blocking

```swift
// When limit is reached, apply restrictions
let store = ManagedSettingsStore()
store.application.blockedApplications = selectedApplications
store.shield.applications = selectedApplications

// After payment, temporarily remove restrictions
store.application.blockedApplications = nil
store.shield.applications = nil

// Re-apply restrictions after unlock time expires
DispatchQueue.main.asyncAfter(deadline: .now() + unlockDuration) {
    store.application.blockedApplications = selectedApplications
    store.shield.applications = selectedApplications
}
```

---

## Database Schema Relationships

```sql
Users (1) ←→ (N) Purchases ←→ (1) Charities
   │                               │
   └── (1) selected_charity ───────┘

Charities (1) ←→ (N) MonthlyReports

Purchase Calculation:
- amountCents = user_paid_amount (e.g., $1.99 = 199 cents)
- appleFeesCents = amountCents * 0.30 (Apple's cut)
- netRevenue = amountCents - appleFeesCents
- charityDonationCents = netRevenue * 0.10 (10% to charity)
- platformRevenueCents = netRevenue * 0.90 (90% to platform)
```

---

## Deployment Architecture

### iOS App Deployment

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Developer  │───►│   Xcode     │───►│ TestFlight  │───►│ App Store   │
│   Build     │    │   Archive   │    │   Beta      │    │   Release   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Backend Deployment

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   GitHub    │───►│   Railway   │───►│ PostgreSQL  │    │   Admin     │
│  Repository │    │   Deploy    │    │  Database   │    │ Dashboard   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

---

## Performance & Scaling Considerations

### iOS App Performance
- **SwiftUI + Combine**: Reactive UI updates
- **Local Caching**: Minimize API calls
- **Background Processing**: Handle monitoring without affecting UI
- **Memory Management**: Proper cleanup of Screen Time resources

### Backend Scaling
- **Stateless API**: Horizontal scaling capability
- **Database Indexing**: Optimized queries for user/purchase lookups
- **Connection Pooling**: Efficient database connections
- **Caching Strategy**: Redis for frequently accessed data (future)

### Database Optimization
```sql
-- Key indexes for performance
CREATE INDEX idx_purchases_user_id ON purchases(user_id);
CREATE INDEX idx_purchases_created_at ON purchases(created_at);
CREATE INDEX idx_purchases_charity_id ON purchases(charity_id);
CREATE INDEX idx_monthly_reports_month_year ON monthly_reports(month, year);
```

This architecture provides a solid foundation for the MindLock app while maintaining security, performance, and scalability as the user base grows. 