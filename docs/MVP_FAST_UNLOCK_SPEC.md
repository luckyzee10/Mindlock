# MindLock MVP Restructure – Two-Tier Unlock Flow

## Purpose
Ship a stripped-down MindLock experience focused on its core value: enforce Screen Time limits and provide a frictionless unlock flow with transparent charity impact. Everything outside the essential loop (analytics, profile, multi-tier pricing) is deferred.

## Goals
- Replace the existing multi-option, difficulty-based unlock system with two choices:
  - **10-minute wait** — free unlock that requires a 30-second “pause and reflect” countdown before granting 10 minutes of access.
  - **MindLock+ upgrade** — auto-renewable subscription (monthly or annual) that unlocks premium analytics, unlimited time blocks, and charity impact tracking.
- Remove unused/unfinished tabs (Analytics, Social, Profile) so the UI centers on setup + current limit status.
- Keep charity tracking intact: every paid unlock contributes 15% of net revenue to the user’s selected charity.

## Scope Overview
| Area | Changes |
| --- | --- |
| Onboarding / Setup | Drop difficulty selection, clarify pricing, keep charity selection (unless we later defer). |
| Unlock UX | Two tiles (free wait vs. MindLock+ upgrade), new countdown microinteraction for the free option, simplified StoreKit flow. |
| Screen Time / Limits | Update `ScreenTimeManager` & `DailyLimitsManager` logic to support only two unlock states. |
| Navigation | `MainTabView` should only expose the dashboard/setup experience. Remove Social, Profile, Analytics. |
| Backend / Docs | Update purchase payload expectations, donation math, and guides (BACKEND_GUIDE, USER_FLOW_LOGIC, PAYMENT_GUIDE). |

## Detailed Requirements

### 1. Onboarding & Setup
1. **Welcome + Mission**: highlight “Stay focused. Unlock with intention. MindLock+ memberships donate to charity.”
2. **Daily Limit Picker**: unchanged (still require users to set allowed time).
3. **Charity Selection**: allow users to **skip** during onboarding (default to “choose a cause later”). Prompt again the first time they attempt a paid unlock so every MindLock+ purchase has a charity attached.
4. **Unlock Explainer Card** (new copy):
   - “Need a quick break? Wait 30 seconds to unlock 10 minutes.”
   - “Need the full suite? Join MindLock+ and automatically donate up to 20% of your plan.”
5. **DifficultySelectionView.swift**: remove from navigation + delete dead code/strings once the plan is final.

### 2. Unlock Flow UX
1. **UnlockPromptView**
   - Show only two `UnlockOption` models (`.timedWait`, `.subscriptionUnlock`).
   - Display pricing (“Free · wait 30s” / “$1 all-MindLock+”).
2. **10-Minute Wait Path**
   - Tapping starts 30-second countdown UI (modal or inline). Disable leaving the screen to prevent abuse.
   - After countdown, call `DailyLimitsManager.grantTemporaryUnlock(duration: 10 minutes)`.
3. **MindLock+ Path**
   - Initiate StoreKit product `mindlock.plus.monthly` / `mindlock.plus.annual`.
   - On success, mark user as unlocked until midnight; record purchase for donation.
   - Handle errors/cancellations with simple messaging (no retry maze).
4. **Shared Charity Banner**: mention “15% of each MindLock+ funds your chosen charity.”

### 3. Screen Time Enforcement / Logic
1. Remove difficulty tiers and multi-duration arrays from:
   - `DailyLimits.swift` (simplify pricing enums).
   - `DailyLimitsManager.swift`
   - Any config in `SharedSettings` relating to pricing or unlock levels.
2. `DailyLimitsManager` responsibilities:
   - Track current status: `.locked`, `.waitingCountdown`, `.timedUnlock(expiration)`, `.subscriptionUnlock(expiration)`.
   - Provide a single API for UI to check whether the lock is active.
3. Reset unlock state at midnight (existing rollover code should already handle this—verify!).

### 4. Navigation & UI Cleanup
1. `MainTabView` should include only:
   - **Status / Unlock** — primary screen that shows remaining time, unlock CTA, and link to adjust limits.
   - Optionally, a separate **Setup** tab if we still want a gear icon for editing limits/charity; otherwise consolidate into one screen.
2. Remove Social, Profile, Analytics tabs entirely (and delete their view files or move to `Deprecated`).
3. `DashboardView` isn’t referenced anywhere; delete it unless we reuse parts of its UI for the Status screen.
4. Remove “Coming Soon” placeholders since those tabs are hidden.

### 5. Backend / Documentation Updates
1. `docs/BACKEND_GUIDE.md`: adjust Apple fee to 15%, donation formula to 15% of net, describe only one SKU.
2. `docs/PAYMENT_GUIDE.md` & `docs/USER_FLOW_LOGIC.md`: replace unlock flow diagrams with the new two-option path.
3. Confirm the mobile app still posts purchase receipts (no change in endpoint) but now always passes productId = `mindlock.plus.monthly` / `mindlock.plus.annual`.
4. Ensure logs/telemetry mark free waits vs. paid passes for monthly reporting.

## Implementation Order
1. **Docs** – update guides so everyone understands the new flow before coding.
2. **Navigation cleanup** – remove unused tabs early to simplify testing.
3. **Setup/Onboarding screens** – delete difficulty view, update copy.
4. **Unlock UI** – refactor prompt view, countdown UI, add two-option view model.
5. **Manager logic** – simplify `DailyLimitsManager`/`ScreenTimeManager`.
6. **StoreKit configuration** – verify product ID, update receipt handling stubs.
7. **QA** – device testing for wait countdown, MindLock+, midnight rollover.

## Open Questions
1. Dashboard vs. Setup: verify whether `DashboardView` is still referenced anywhere. If it’s only an artifact of the old tab structure, delete it and route everything through a single Status/Setup screen.

_(Countdown behavior resolved: the 30‑second wait should pause if the app backgrounds and resume when the user returns.)_

Let me know the answers to the open questions (or any additional scope changes), and I’ll refine the spec before we start implementing.
