# MindLock User Flow Logic Document

## 📋 **Document Overview**

This document defines the complete user experience flow for MindLock, including system architecture, data flows, and UI wireframes. It serves as the single source of truth for implementation decisions.

> **Fast MVP Update (Nov 2025)**  
> - Navigation trimmed to two tabs: **Status** (current lock state + unlock CTA) and **Setup** (limits, charity). Analytics/Social/Profile are deferred.  
- Unlock flow now has only two paths: a free 30-second wait that grants 10 minutes, and a MindLock+ subscription upsell that unlocks premium tools while funding the user’s charity.  
> - Charity selection can be skipped during onboarding; we prompt again before the first paid unlock.  
> - Difficulty tiers, multi-duration products, and per-app unlock paywalls have been removed to reduce friction.
> 
> The remaining sections still describe the full architecture, but the items above represent the MVP scope we are implementing now.

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
App Selection → Limit Setting → Charity Selection (skip allowed) → 
Concept Explanation → Main App
```

### **Flow 2: Daily Limit Management**
```
Setup Tab → Adjust Limits → Warning: "Changes apply at midnight" → 
Save → Limits Apply at Midnight
```

### **Flow 3: Limit Exceeded & Unlock**
```
App Usage Hits Limit → Blocking Screen → Unlock Prompt
    ↳ Option A: Wait 30 seconds → 10-minute unlock
    ↳ Option B: Join MindLock+ → Unlock premium tools + donation tracking
```

### **Flow 4: Analytics & Progress**
_Deferred for MVP_

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
**Purpose**: Present the two unlock choices and process MindLock+ subscription receipts.

**Components:**
- `UnlockPromptView` (wait vs. MindLock+ UI + countdown)
- `DailyLimitsManager.grantFreeUnlock`
- `PaymentManager` (StoreKit 2, SKUs `mindlock.plus.monthly` / `mindlock.plus.annual`)

**Key Functions:**
- `startCountdown()` – Runs the 30-second wait, then grants a 10-minute temporary unlock.
- `purchaseSubscription(charity)` – Triggers StoreKit, validates receipt, donates up to 20% of net revenue, and refreshes MindLock+ status.
- `refreshBlockingNow()` – Reapplies ManagedSettings when the unlock expires.

**Inputs:**
- Limit violation events
- Stored charity preference (optional)
- StoreKit purchase callbacks

**Outputs:**
- Temporary unlock state (free wait)
- MindLock+ subscription status + donation ledger entries (via `SharedSettings.recordDonation`)
- Blocking status updates for the Status tab

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
- Local JSON files via `SharedSettings` (daily limits, usage snapshots, donation summaries)

**Key Functions:**
- `saveUserPreferences()` - Limits, charity
- `loadDailyConfiguration()` - Bootstrap each day
- `recordDonation()` - Append donation metadata for backend rollup

**Inputs:**
- User preference changes
- MindLock+ purchases
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
│ ┌──────┐ ┌─────┐                   │
│ │Status│ │Setup│                   │
│ └──────┘ └─────┘                   │
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
│ └─┘  Choose where day-pass fees go  │
├─────────────────────────────────────┤
│ ┌─┐  Unlock Options                 │
│ │🔓│  10m wait / MindLock+ upgrade  > │
├─────────────────────────────────────┤
│          Quick Stats                │
│   📊 3 apps configured              │
│   💰 Up to 20% of MindLock+ net donated     │
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
