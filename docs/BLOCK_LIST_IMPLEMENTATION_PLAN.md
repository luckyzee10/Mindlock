# Block List Implementation Plan

This document maps out the code and UX changes required to introduce a first-class “Block List” that powers Time Blocks while keeping per-app limits independent. It also covers how the two enforcement systems interact so we avoid regressions in Screen Time monitoring.

---

## 1. Goals
- Let users pick a reusable set of distracting apps (“Block List”) that Time Blocks shield as a group.
- Keep App Limits fully customizable per app; no automatic limit creation when Block List changes.
- Clarify onboarding and reviewer flows so selecting apps no longer implies immediate blocking.
- Provide editing tools + tooltips after onboarding so users understand each feature.
- Ensure Time Blocks and App Limits behave nicely when both apply to the same app (e.g., breaks, streak tracking).

---

## 2. Data & Persistence Changes
1. **BlockListManager**
   - Introduce a dedicated lightweight singleton (`BlockListManager`) that wraps the existing `FamilyActivitySelection`.
   - Methods: `currentSelection`, `update(selection:reason:)`, `applicationTokens`, `contains(token)`.
   - Storage: reuse `SharedSettings.persistSelection` and app-group defaults so extensions see the same list.

2. **Separation from Limits**
   - Remove the onboarding `setLimitImmediate` loop; `DailyLimitsManager` only changes when the user edits limits later.
   - Ensure `ScreenTimeManager.configureDailyMonitoring` gracefully handles empty limit sets (so we can still apply Time Blocks via ManagedSettings even if no limits exist).
   - SharedSettings now exposes a `ShieldSnapshot` (limit shields + block shields + temp unlocks) so the app/UI has a single ledger to read from instead of piecing together multiple caches.

3. **Time Block Shielding**
   - When a Time Block fires, apply ManagedSettings shields to `blockListTokens`.
   - Breaks (temporary unlocks) should only pause the shield; they should not decrement daily limit usage. We already prevent usage accumulation when `SharedSettings.hasActiveTemporaryUnlock`, so no extra work is needed beyond confirming the shields call into `DailyLimitsManager.refreshBlockingNow()` after a break expires.

---

## 3. UI / UX Updates
### 3.1 Onboarding (“How Limits Work” page)
- Copy: “Pick your first block list. We only block these apps when you run a Time Block.”
- UI: show a sortable list of selected apps (using `Label(applicationToken)`), but remove the per-app limit picker chips.
- Actions: “Select apps to block” ➜ launches the FamilyControls picker. “Continue” saves the selection via `BlockListManager.update` and moves forward.
- Optional: if we want to prompt “Set limits now”, link to App Limits after onboarding finishes instead of inside this screen.

### 3.2 Post-Onboarding Setup
- Keep the main “Time Blocks” card in `SetupView`, and embed the Block List entry point inside that card so it’s visually part of the Time Block system (“Block List (used by Time Blocks)” row).
- Tapping the embedded row pushes a `BlockListEditorView` that only handles selection (no limit sliders). Returning drops the user back into the Time Blocks detail view.
- App Limits screen starts empty after onboarding; users add apps within that view and assign minutes per app entirely independently of the block list.
- The Time Blocks editor should clearly state it uses the Block List (“This block locks every app on your Block List”). If the list is empty, prompt the user to populate it before creating blocks.

---

## 4. Tooltip Rollout After Onboarding
Use a shared `CoachMarkView` + `@AppStorage` flags so each appears once.

1. **App Limits Tooltip**
   - Trigger: first time the user opens Setup after onboarding.
   - Message: “Set daily minutes per app. When time runs out, MindLock blocks that app until tomorrow.”

2. **Time Blocks Tooltip**
   - Trigger: same visit, auto-positioned near the Time Blocks card.
   - Message: “Schedule focus sessions. When a block runs, every app on your Block List is locked.”

3. **Block List Tooltip**
   - Trigger: when the user first visits the new Block List editor.
   - Message: “Create your block list for Time Blocks here. Time Blocks reference this list; App Limits are configured separately.”

4. **Create First Block Prompt**
   - Trigger: user exits Setup without any blocks defined.
   - Message: “Tap Time Blocks to create your first focus session.”
   - Dismissed once they create a block or tap “Got it”.

---

## 5. Interaction Between Limits and Time Blocks
- **When both apply to the same app:**
  - Time Block active → ManagedSettings shields the app regardless of remaining daily minutes.
  - Break granted during a Time Block → we temporarily allow the app; use existing `SharedSettings.hasActiveTemporaryUnlock` flag so usage during the break does *not* consume daily limit minutes.
  - Time Block ends → shields revert to the state dictated by daily limits. If the user already hit their limit earlier, the app remains blocked; otherwise it’s accessible until they run out of minutes again.

- **Analytics / impact tracking:**
  - Daily limit overages still increment impact metrics when the user pays to unlock.
  - Time Blocks contribute to “streak” logic separately; we just need to ensure hitting a block doesn’t accidentally flag “limit reached” events.

---

## 6. App Review & Testing Notes
- Submission notes should explain:
  1. Select apps in onboarding → completes the Block List.
  2. To see immediate blocking, either (a) start a Time Block (shield applies instantly) or (b) visit App Limits, set a 1-minute limit, and hit that limit.
  3. Breaks pause Time Blocks without consuming app limits.
- Add a Reviewer toggle (debug-only) that starts a short Time Block covering the entire Block List so they can confirm blocking quickly.

---

## 7. Implementation Steps
1. Create `BlockListManager` with clear API + storage.
2. Refactor onboarding to use the new manager and remove limit pickers.
3. Add the Block List editor to Setup; wire Time Blocks to reference the selection.
4. Audit Time Block shielding/break code to ensure it respects the new data flow.
5. Implement tooltips + reviewer toggle.
6. Update docs (README, IOS_GUIDE) and App Store submission notes to describe the new flow.
7. Regression test: onboarding → select apps → create time block → confirm shield; set app limit → hit limit; combine both scenarios on simulator and physical device.

This plan keeps App Limits and Time Blocks complementary, aligns onboarding copy with actual behavior, and gives App Review a deterministic way to validate blocking.
