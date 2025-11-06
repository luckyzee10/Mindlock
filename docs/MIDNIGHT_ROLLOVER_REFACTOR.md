## Midnight Rollover Refactor – Implementation Checklist

### 1. Shared storage for limits & usage
- [ ] Extend `SharedSettings` with new keys under `sharedDefaults` for:
  - current limits snapshot
  - pending limits snapshot
  - today usage snapshot
  - (optional) rollover heartbeat timestamp
- [ ] Introduce small `Codable` helper types inside `SharedSettings` (e.g. `StoredDailyLimits`, `StoredUsage`) so both the app and extensions can encode/decode without depending on `DailyLimitsManager`.
- [ ] Add helper functions:
  ```swift
  static func storeCurrentLimits(_ snapshot: StoredDailyLimits)
  static func loadCurrentLimits() -> StoredDailyLimits?
  static func storePendingLimits(_ snapshot: StoredDailyLimits)
  static func loadPendingLimits() -> StoredDailyLimits?
  static func storeTodayUsage(_ usage: StoredUsage)
  static func loadTodayUsage() -> StoredUsage?
  ```

### 2. Shared midnight rollover helper
- [ ] Add a method such as `SharedSettings.performMidnightRollover()` that:
  - Reads current & pending snapshots.
  - Promotes pending ➜ current (fallback to current if pending missing).
  - Resets today’s usage snapshot.
  - Writes the refreshed snapshots back to shared defaults.
  - Returns the new `StoredDailyLimits` + `StoredUsage` so callers can update in‑memory state if needed.

### 3. Update `DailyLimitsManager`
- [ ] Remove the old `Keys` struct entries and `UserDefaults.standard` storage for limits/usage (`currentLimits`, `pendingLimits`, `todayUsage`).
- [ ] Update `loadStoredData()` to pull from `SharedSettings` snapshots (and fall back to defaults if nil).
- [ ] Update `saveCurrentLimits()`, `savePendingLimits()`, `saveTodayUsage()` to write through the new shared helper functions.
- [ ] Replace `applyMidnightTransition()` logic with a call to `SharedSettings.performMidnightRollover()`; apply the returned snapshots to `currentLimits`, `pendingLimits`, `todayUsage`, then call `recomputeBlockingAfterLimitChange()` and continue the existing notification flow.
- [ ] Ensure any references to the removed storage code are deleted (e.g. no lingering `userDefaults.data(forKey: Keys.currentLimits)` calls).

### 4. Update `MindLockActivityMonitor`
- [ ] In `intervalDidStart`, for every non-demo activity:
  - Call `SharedSettings.performMidnightRollover()` to refresh shared snapshots.
  - Clear shields (`ManagedSettingsStore().shield.applications = []`).
  - Reset shared blocking state (`SharedSettings.setBlockingState(false)`) and clean up pending limit-event metadata (last event name / tokens).
- [ ] Keep the existing demo bypass so the analytics demo remains untouched.

### 5. Cleanup / validation
- [ ] Verify there are no leftover helpers/keys tied to the removed storage (search for deleted constants).
- [ ] Confirm both the app target and monitor target compile (SharedSettings is already part of both).
- [ ] Manual test plan:
  1. Set limits, schedule pending change, force-quit MindLock before midnight.
  2. Let the system roll past midnight.
  3. Unlock device: apps should be unblocked immediately; when MindLock launches, `DailyLimitsManager` should load the promoted limits/usage from SharedSettings without running extra rollover logic.

