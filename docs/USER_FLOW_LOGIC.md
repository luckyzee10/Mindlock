# MindLock User Flow Logic Document

## 📋 **Document Overview**

This document defines the complete user experience flow for MindLock, including system architecture, data flows, and UI wireframes. It serves as the single source of truth for implementation decisions.

---

## 🎯 **Core Value Proposition**

**"Turn screen time slips into charitable impact through next-day accountability"**

- Users set app limits that apply the following day
- When limits are exceeded, users choose a charity and pay to unlock
- 50% of payment goes to chosen charity, creating positive impact from negative moments

---

## 🔄 **Primary User Flows**

### **Flow 1: Initial Setup & Onboarding**
```
Start → Welcome → Usage Survey → Screen Time Permission → 
App Selection → Limit Setting → Charity Selection → 
Difficulty Level → Concept Explanation → Main App
```

### **Flow 2: Daily Limit Management**
```
Setup Tab → Adjust Limits → Warning: "Changes apply at midnight" → 
Save → Limits Apply at Midnight
```

### **Flow 3: Limit Exceeded & Unlock**
```
App Usage Hits Limit → Blocking Screen → 
Choose Charity → Select Duration → Payment → 
Temporary Unlock → Impact Confirmation
```

### **Flow 4: Analytics & Progress**
```
Analytics Tab → Today's Usage → Weekly Trends → 
App Breakdown → Goal Progress → Social Impact
```

---

## 🏗️ **System Architecture & Modules**

### **Module 1: Limit Management System**
**Purpose**: Handle daily limits with next-day application logic

**Components:**
- `DailyLimitsManager` (singleton)
- `DailyLimits` (data model)
- `AppUsageDay` (usage tracking)

**Key Functions:**
- `setLimit(app, duration)` - Changes apply at midnight
- `getCurrentLimit(app)` - Active limits for today
- `hasExceededLimit(app)` - Check violation status
- `applyMidnightTransition()` - Apply new limits at 12 AM

**Inputs:**
- User limit adjustments (apply at midnight)
- Real-time app usage data
- Midnight timer events

**Outputs:**
- Current active limits
- Pending limit changes
- Limit violation triggers
- Usage analytics data

### **Module 2: Unlock & Payment System**
**Purpose**: Handle charity selection and unlock purchases

**Components:**
- `UnlockFlowView` (charity selection UI)
- `PaymentManager` (Apple IAP integration)
- `UnlockTransaction` (transaction logging)

**Key Functions:**
- `presentUnlockFlow(app)` - Show charity selection
- `purchaseUnlock(duration, charity, amount)` - Process payment
- `temporaryUnblock(app, duration)` - Grant access
- `logTransaction(details)` - Record for reporting

**Inputs:**
- Limit violation events
- User charity selection
- User unlock duration choice
- Payment completion callbacks

**Outputs:**
- Charity donation transactions
- Temporary app access grants
- Impact reporting data
- Revenue tracking

### **Module 3: Screen Time Integration**
**Purpose**: Monitor usage and enforce blocking

**Components:**
- `ScreenTimeManager` (existing, enhanced)
- `DeviceActivityMonitor` (usage tracking)
- `ManagedSettings` (app blocking)

**Key Functions:**
- `monitorUsage(apps)` - Track real-time usage
- `blockApps(list)` - Enforce restrictions
- `unblockTemporarily(app, duration)` - Unlock flow
- `requestPermissions()` - Get Screen Time access

**Inputs:**
- Active app limit configurations
- Real-time device usage
- Unlock purchase confirmations

**Outputs:**
- Usage duration per app
- Limit violation events
- Blocking enforcement
- Permission status

### **Module 4: Data Persistence**
**Purpose**: Store user preferences and transaction history

**Components:**
- `UserDefaults` (preferences)
- `CoreData/SQLite` (transactions - future)
- Local JSON files (backup)

**Key Functions:**
- `saveUserPreferences()` - Limits, charity, pricing
- `loadDailyConfiguration()` - Bootstrap each day
- `syncTransactionHistory()` - Backend integration
- `exportDonationReport()` - Monthly summaries

**Inputs:**
- User preference changes
- Transaction completions
- Configuration updates

**Outputs:**
- Persisted user state
- Transaction history
- Donation reports
- Backup data files

---

## 📱 **UI Wireframe Sketches**

### **1. Main Tab Structure**
```
┌─────────────────────────────────────┐
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │Setup│ │Analyt│ │Social│ │Profil│   │
│ └─────┘ └─────┘ └─────┘ └─────┘    │
├─────────────────────────────────────┤
│              CONTENT                │
│                                     │
│         (Tab-specific views)        │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### **2. Setup Tab Layout**
```
┌─────────────────────────────────────┐
│           Setup Your Limits         │
├─────────────────────────────────────┤
│ ┌─┐  App Limits                     │
│ │📱│  [IG] [TT] [FB] +3        > │
│ └─┘  Set daily time limits          │
├─────────────────────────────────────┤
│ ┌─┐  Your Charity                   │
│ │💝│  World Wildlife Fund        > │
│ └─┘  Choose where fees go           │
├─────────────────────────────────────┤
│ ┌─┐  Difficulty Level               │
│ │⚖️│  Balanced Mode              > │
│ └─┘  $1.00 • $2.00 • $3.00         │
├─────────────────────────────────────┤
│          Quick Stats                │
│   📊 3 apps configured              │
│   💰 $12 donated this month         │
└─────────────────────────────────────┘
```

### **3. App Limits Configuration**
```
┌─────────────────────────────────────┐
│            App Limits               │
├─────────────────────────────────────┤
│ [IG icon] Instagram   [1h 30m] ⚙️   │
│                      1h 23m left    │
│                                     │
│ [TT icon] TikTok     [45m] ⚙️       │
│                      12m left       │
│                                     │
│ [FB icon] Facebook   [2h] ⚙️        │
│                      2h 05m left    │
├─────────────────────────────────────┤
│ ⚠️ Changes apply at midnight         │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │         Save Changes            │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### **4. Unlock Flow - Charity Selection**
```
┌─────────────────────────────────────┐
│ ✕                           Cancel  │
├─────────────────────────────────────┤
│ [IG icon] Time's up                 │
│           You've used your 2h limit │
├─────────────────────────────────────┤
│      Turn this moment into impact   │
│    Choose who benefits from your    │
│           extra time                │
├─────────────────────────────────────┤
│ ┌─┐ American Red Cross              │
│ │🏥│ Disaster relief & emergency    │
│ └─┘ assistance               >     │
├─────────────────────────────────────┤
│ ┌─┐ World Wildlife Fund             │
│ │🐼│ Conservation & environmental   │
│ └─┘ protection              >      │
├─────────────────────────────────────┤
│ ┌─┐ Feeding America                 │
│ │🍎│ Fighting hunger across the US  │
│ └─┘                         >      │
└─────────────────────────────────────┘
```

### **5. Unlock Flow - Duration Selection**
```
┌─────────────────────────────────────┐
│ Supporting: World Wildlife Fund     │
│ [Change]                            │
├─────────────────────────────────────┤
│ ┌─┐ WWF                            │
│ │🐼│ Conservation & environmental    │
│ └─┘ protection                      │
├─────────────────────────────────────┤
│      Choose your extra time         │
├─────────────────────────────────────┤
│ ● 1 hour          $1.00  Funds 1 meal│
│   2 hours         $2.00  Funds 2 meals│
│   Rest of day     $3.00  Funds 3 meals│
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │    Continue with 1 hour   $1.00 │ │
│ └─────────────────────────────────┘ │
│                                     │
│      I'm done for today             │
└─────────────────────────────────────┘
```

### **6. Analytics Dashboard**
```
┌─────────────────────────────────────┐
│           Today's Progress          │
├─────────────────────────────────────┤
│ Screen Time: 3h 24m    Goal: 4h    │
│ ████████████░░░░  85%               │
├─────────────────────────────────────┤
│ Time Off Screen: 12h 36m            │
│ ████████████████████  📈            │
├─────────────────────────────────────┤
│            App Breakdown            │
│ Instagram     1h 45m  ████████░░    │
│ TikTok        58m     ██████░░░░    │
│ Facebook      41m     ████░░░░░░    │
├─────────────────────────────────────┤
│         This Week's Impact          │
│ 💝 Donated: $8.50 to 3 charities   │
│ 📊 Unlocks: 5 times                │
│ 🎯 Goal days: 4/7                  │
└─────────────────────────────────────┘
```

---

## 🔄 **State Transition Diagrams**

### **Daily Limit Lifecycle**
```
User Sets Limits (Anytime)
         ↓ (Midnight)
Limits Become Active
         ↓ (Usage)
Limit Exceeded
         ↓ (User Choice)
[Unlock Flow] OR [Stop Using]
         ↓
[Temporary Access] OR [Blocked]
         ↓ (Next Midnight)
New Limits Apply (if changed)
```

### **Unlock Flow State Machine**
```
App Blocked → Charity Selection → Duration Selection → 
Payment Processing → [Success: Temporary Unlock] OR 
[Failure: Remain Blocked] → Impact Confirmation
```

---

## 💫 **Key User Experience Principles**

### **1. Psychological Empowerment**
- **Never trap users**: Always show "adjust tomorrow" option
- **Positive framing**: "Turn slip into impact" not "pay penalty"
- **Choice in the moment**: User picks charity when emotionally engaged

### **2. Midnight Accountability**
- **Limits can be changed anytime**: User feels in control
- **Changes apply at midnight**: Clear daily reset boundary
- **Warning messaging**: "Changes apply at midnight" keeps users informed

### **3. Charitable Impact Focus**
- **50% to charity**: Real impact, not just profit
- **Moment of choice**: Select charity during unlock for emotional connection
- **Impact visualization**: Show real-world effects of donations

### **4. Progressive Difficulty**
- **User-selected pricing**: Respect their chosen commitment level
- **Graduated options**: Multiple unlock durations
- **Escape valves**: "Done for today" always available

---

## 📊 **Data Flow Architecture**

```
User Actions → Local State → UserDefaults → Daily Reset
     ↓             ↓             ↓            ↓
Screen Time API ← Limit Manager ← Persistence ← Timer Events
     ↓             ↓             ↓            ↓
Usage Events → Violation Check → Unlock Flow → Payment
     ↓             ↓             ↓            ↓
Analytics ← Transaction Log ← Charity Impact ← Revenue Split
```

---

## 🎛️ **System Inputs & Outputs Summary**

### **System Inputs**
- User limit preferences (apply at midnight)
- Real-time app usage data (Screen Time API)
- Charity selection during unlock
- Unlock duration and payment choices
- Midnight timer triggers

### **System Outputs**
- App blocking enforcement (ManagedSettings)
- Unlock flow presentation (UI)
- Charity donation transactions (Apple IAP)
- Usage analytics and trends (Dashboard)
- Monthly donation reports (Export)

### **Critical Decision Points**
1. **Limit exceeded**: Block or allow unlock flow?
2. **Charity selection**: Which cause to support?
3. **Unlock duration**: How much extra time?
4. **Payment processing**: Complete transaction?
5. **Midnight transition**: Apply new limits?

---

## 🚀 **Implementation Priority**

### **Phase 1: Core Flow (Current)**
- [x] Setup section with next-day limits
- [x] Unlock flow with charity selection  
- [ ] Actual Screen Time blocking integration
- [ ] Payment processing (Apple IAP)

### **Phase 2: Polish & Analytics**
- [ ] Analytics dashboard with real data
- [ ] Usage monitoring and trend analysis
- [ ] Impact visualization and reporting

### **Phase 3: Social & Advanced**
- [ ] Social features and leaderboards
- [ ] Profile section with goals and achievements
- [ ] Backend integration and multi-device sync

This document serves as our north star for building MindLock with intention and clarity. Every implementation decision should trace back to these core flows and principles. 