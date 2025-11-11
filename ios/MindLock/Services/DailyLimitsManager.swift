import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

@MainActor
class DailyLimitsManager: ObservableObject {
    static let shared = DailyLimitsManager()
    
    // MARK: - Published Properties
    @Published var currentLimits: DailyLimits
    @Published var pendingLimits: DailyLimits
    @Published var todayUsage: AppUsageDay
    @Published var isBlocking: Bool = false
    @Published var recentlyBlockedTokens: [ApplicationToken] = []
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let lastMidnightCheck = "lastMidnightCheck"
    }
    
    init() {
        let today = Date()
        
        // Initialize with default values
        self.currentLimits = DailyLimits(date: today, isActive: true)
        self.pendingLimits = DailyLimits(date: today)
        self.todayUsage = AppUsageDay(date: today)
        
        loadStoredData()
        startMidnightTimer()
        isBlocking = SharedSettings.sharedBlockingState()
        DispatchQueue.main.async {
            ScreenTimeManager.shared.refreshMonitoringSchedule(reason: "launch")
        }

        print("📅 DailyLimitsManager initialized for \(dateString(today))")
    }

    // MARK: - Public Methods
    
    /// Set a limit and ensure the current active limits reflect it immediately.
    /// Use this for immediate updates in settings flows.
    func setLimit(for token: ApplicationToken, limit: TimeInterval) {
        // Update both current and pending so midnight keeps the same value
        currentLimits.setLimit(for: token, limit: limit)
        pendingLimits.setLimit(for: token, limit: limit)
        saveCurrentLimits()
        savePendingLimits()
        ScreenTimeManager.shared.refreshMonitoringSchedule(reason: "limit updated")
        recomputeBlockingAfterLimitChange()
        print("📝 Set limit for app: \(formatTime(limit)) (active now)")
    }

    /// Explicit immediate setter for onboarding to avoid any confusion in logs/copy.
    func setLimitImmediate(for token: ApplicationToken, limit: TimeInterval) {
        currentLimits.setLimit(for: token, limit: limit)
        pendingLimits.setLimit(for: token, limit: limit)
        saveCurrentLimits()
        savePendingLimits()
        ScreenTimeManager.shared.refreshMonitoringSchedule(reason: "onboarding limit set")
        recomputeBlockingAfterLimitChange()
        print("📝 Onboarding set limit: \(formatTime(limit)) (active now)")
    }

    /// Defer a limit update to tomorrow without touching the current limits.
    func setPendingLimitOnly(for token: ApplicationToken, limit: TimeInterval) {
        pendingLimits.setLimit(for: token, limit: limit)
        savePendingLimits()
    }

    /// Defer removal of an app from the limited list by removing it from pending limits (will take effect at midnight).
    func deferRemoval(for token: ApplicationToken) {
        // Remove from pending limits; current limits remain until midnight
        pendingLimits.appLimits.removeValue(forKey: token.identifier)
        savePendingLimits()
    }

    /// Remove an app's limit immediately from both current and pending, then refresh monitoring and blocking.
    func removeLimitImmediate(for token: ApplicationToken) {
        currentLimits.appLimits.removeValue(forKey: token.identifier)
        pendingLimits.appLimits.removeValue(forKey: token.identifier)
        saveCurrentLimits()
        savePendingLimits()
        ScreenTimeManager.shared.refreshMonitoringSchedule(reason: "limit removed")
        recomputeBlockingAfterLimitChange()
        print("📝 Removed limit for app immediately")
    }
    
    /// Get current active limit for an app
    func getCurrentLimit(for token: ApplicationToken) -> TimeInterval? {
        return currentLimits.limitForApp(token)
    }
    
    /// Get pending limit for an app (what will be active after midnight)
    func getPendingLimit(for token: ApplicationToken) -> TimeInterval? {
        return pendingLimits.limitForApp(token)
    }
    
    /// Check if app has exceeded its limit today
    func hasExceededLimit(for token: ApplicationToken) -> Bool {
        if SharedSettings.hasActiveTemporaryUnlock(for: token) {
            return false
        }
        guard let limit = getCurrentLimit(for: token) else { return false }
        return todayUsage.hasExceededLimit(for: token, limit: limit)
    }
    
    /// Get remaining time for an app today
    func getRemainingTime(for token: ApplicationToken) -> TimeInterval {
        guard let limit = getCurrentLimit(for: token) else { return .infinity }
        if let expiry = SharedSettings.temporaryUnlockExpiry(for: token) {
            return max(0, expiry.timeIntervalSinceNow)
        }
        return todayUsage.remainingTimeForApp(token, limit: limit)
    }
    
    /// Record app usage (called by monitoring system)
    func recordUsage(for token: ApplicationToken, duration: TimeInterval) {
        todayUsage.addUsage(for: token, duration: duration)
        saveTodayUsage()
        
        // Check if limit exceeded and trigger blocking if needed
        if hasExceededLimit(for: token) {
            triggerBlocking(for: token)
        }
    }

    /// Demo helper to schedule a short 1-minute monitoring window for the first selected app
    func scheduleOneMinuteDemo() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            print("⚠️ Cannot schedule demo: not authorized")
            return
        }
        
        let selectedTokens = ScreenTimeManager.shared.selectedApps.applicationTokens
        guard !selectedTokens.isEmpty else {
            print("⚠️ Cannot schedule demo: no selected apps")
            return
        }

        print("🧪 Preparing analytics demo for tokens: \(selectedTokens.map { $0.identifier })")

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        var eventMap: [String: [String]] = [:]
        for (index, token) in selectedTokens.enumerated() {
            let limit = Int(min(getCurrentLimit(for: token) ?? 60, 60))
            let threshold = max(limit, 10) // ensure a reasonable minimum
            let eventName = DeviceActivityEvent.Name("demo_limit_\(index)")
            if #available(iOS 17.4, *) {
                events[eventName] = DeviceActivityEvent(
                    applications: [token],
                    threshold: DateComponents(second: threshold),
                    includesPastActivity: true
                )
            } else {
                events[eventName] = DeviceActivityEvent(
                    applications: [token],
                    threshold: DateComponents(second: threshold)
                )
            }
            eventMap[eventName.rawValue] = [token.identifier]
        }

        guard !events.isEmpty else {
            print("⚠️ Cannot schedule demo: no events configured")
            return
        }

        let now = Date()
        let end = now.addingTimeInterval(30 * 60)
        let components: Set<Calendar.Component> = [.hour, .minute, .second]
        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: now),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )

        let center = DeviceActivityCenter()
        do {
            let demoActivity = DeviceActivityName("MindLockDemo")
            center.stopMonitoring([demoActivity])
            try center.startMonitoring(demoActivity, during: schedule, events: events)
            SharedSettings.persistEventTokenMap(eventMap)
            print("🧪 Scheduled demo monitoring window with \(events.count) event(s)")

#if DEBUG
            Task.detached {
                for attempt in 1...6 {
                    try? await Task.sleep(nanoseconds: UInt64(15 * 1_000_000_000))
                    print("📉 Demo poll \(attempt): awaiting system activity snapshot…")
                }
            }
#endif
        } catch {
            print("❌ Demo schedule failed: \(error)")
        }
    }

    func grantFreeUnlock(minutes: Int = 10) {
        let tokens = allLimitedTokens()
        guard !tokens.isEmpty else {
            print("⚠️ Free unlock skipped: no limited apps configured")
            return
        }

        let duration = TimeInterval(minutes * 60)
        let expiry = Date().addingTimeInterval(duration)
        SharedSettings.setTemporaryUnlock(for: tokens, until: expiry)
        SharedSettings.recordUnlock(kind: .free(minutes: Double(minutes)))
        ScreenTimeManager.shared.temporaryUnlock(tokens: tokens, duration: duration)
        recentlyBlockedTokens.removeAll(where: { tokens.contains($0) })
        print("⏳ Granted free unlock for \(minutes) minutes on \(tokens.count) app(s)")
    }

    @discardableResult
    func grantDayPass(charity: Charity?) -> Int? {
        let tokens = allLimitedTokens()
        guard !tokens.isEmpty else {
            print("⚠️ Day pass skipped: no limited apps configured")
            return nil
        }

        let seconds = max(60, secondsUntilMidnight(from: Date()))
        let expiry = Date().addingTimeInterval(seconds)
        SharedSettings.setTemporaryUnlock(for: tokens, until: expiry)
        SharedSettings.recordUnlock(kind: .dayPass(minutes: seconds / 60))
        ScreenTimeManager.shared.temporaryUnlock(tokens: tokens, duration: seconds)
        recentlyBlockedTokens.removeAll(where: { tokens.contains($0) })
        if let charity = charity {
            let donation = dayPassDonationAmount()
            SharedSettings.recordDonation(amount: donation, charityId: charity.id, charityName: charity.name)
            print("💝 Recorded $\(String(format: "%.2f", donation)) donation to \(charity.name)")
        }
        print("🔓 Granted day pass for \(tokens.count) app(s) until midnight")
        return Int(ceil(seconds / 60))
    }
    
    // MARK: - Private Methods

    private func loadStoredData() {
        print("[loadStoredData] start")
        let today = Date()
        let storedCurrent = SharedSettings.loadCurrentLimits()
        let storedPending = SharedSettings.loadPendingLimits()
        let storedUsage = SharedSettings.loadTodayUsage()
        var promotedPending: SharedSettings.StoredDailyLimits?

        if let currentSnapshot = storedCurrent,
           calendar.isDate(currentSnapshot.date, inSameDayAs: today) {
            currentLimits = convert(currentSnapshot)
        } else {
            let rollover = SharedSettings.performMidnightRollover(referenceDate: today)
            currentLimits = convert(rollover.current)
            pendingLimits = convert(rollover.pending)
            todayUsage = convert(rollover.usage)
            promotedPending = rollover.pending
        }

        if let pendingSnapshot = promotedPending ?? storedPending {
            if calendar.isDate(pendingSnapshot.date, inSameDayAs: today) {
                pendingLimits = convert(pendingSnapshot)
            } else {
                pendingLimits = DailyLimits(date: today, appLimits: pendingSnapshot.appSeconds)
                SharedSettings.storePendingLimits(snapshot(from: pendingLimits))
            }
        } else {
            pendingLimits = DailyLimits(date: today, appLimits: currentLimits.appLimits)
            SharedSettings.storePendingLimits(snapshot(from: pendingLimits))
        }

        if promotedPending == nil,
           let usageSnapshot = storedUsage,
           calendar.isDate(usageSnapshot.date, inSameDayAs: today) {
            todayUsage = convert(usageSnapshot)
        } else if promotedPending == nil {
            todayUsage = AppUsageDay(date: today)
            SharedSettings.storeTodayUsage(snapshot(from: todayUsage))
        }

        backfillUsageForPendingBlock()
        recomputeBlockingAfterLimitChange()
        print("[loadStoredData] end")
    }

    /// Reevaluate ManagedSettings blocking after limits change.
    private func recomputeBlockingAfterLimitChange() {
        let selectedTokens = ScreenTimeManager.shared.selectedApps.applicationTokens
        let activeSuppressions = SharedSettings.activeTemporaryUnlocks()
        let suppressedIds = Set(activeSuppressions.keys)
        // Compute the set of tokens that have exceeded their limit
        var blockedSet = Set<ApplicationToken>()
        for token in selectedTokens {
            if suppressedIds.contains(SharedSettings.tokenKey(token)) {
                continue
            }
            if hasExceededLimit(for: token) { blockedSet.insert(token) }
        }

        let store = ManagedSettingsStore()
        if blockedSet.isEmpty {
            store.clearAllSettings()
            isBlocking = false
            recentlyBlockedTokens = []
            SharedSettings.setBlockingState(false)
            print("🔓 Cleared blocking after limit change (no apps exceeded)")
            return
        }

        store.shield.applications = blockedSet
        isBlocking = true
        recentlyBlockedTokens = Array(blockedSet)
        SharedSettings.setBlockingState(true)
        print("🔒 Applied per-app blocking to \(blockedSet.count) app(s)")
    }

    private func backfillUsageForPendingBlock() {
        guard let event = SharedSettings.pendingLimitEvent() else { return }
        var didMutate = false

        for token in event.blockedTokens {
            guard let limit = getCurrentLimit(for: token) else { continue }
            let used = todayUsage.usageForApp(token)
            if used < limit {
                todayUsage.addUsage(for: token, duration: limit - used)
                didMutate = true
            }
        }

        if didMutate {
            saveTodayUsage()
        }
    }
    
    private func saveCurrentLimits() {
        SharedSettings.storeCurrentLimits(snapshot(from: currentLimits))
    }

    private func savePendingLimits() {
        SharedSettings.storePendingLimits(snapshot(from: pendingLimits))
    }

    private func saveTodayUsage() {
        SharedSettings.storeTodayUsage(snapshot(from: todayUsage))
    }
    
    private func startMidnightTimer() {
        // Create a timer that checks for midnight transition
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForMidnightTransition()
            }
            .store(in: &cancellables)
    }
    
    private func checkForMidnightTransition() {
        let now = Date()
        let lastCheck = userDefaults.object(forKey: Keys.lastMidnightCheck) as? Date ?? now
        
        // Check if we've crossed midnight since last check
        if !calendar.isDate(lastCheck, inSameDayAs: now) {
            applyMidnightTransition()
        }
        
        userDefaults.set(now, forKey: Keys.lastMidnightCheck)
    }
    
    private func applyMidnightTransition() {
        print("🌙 Midnight transition: Applying pending limits")

        let rollover = SharedSettings.performMidnightRollover(referenceDate: Date())
        currentLimits = convert(rollover.current)
        pendingLimits = convert(rollover.pending)
        todayUsage = convert(rollover.usage)
        SharedSettings.clearLimitEvent()

        ScreenTimeManager.shared.refreshMonitoringSchedule(reason: "midnight transition")
        recomputeBlockingAfterLimitChange()
        NotificationManager.shared.postSettingsUpdatedNotification()
    }
    
    private func triggerBlocking(for token: ApplicationToken) {
        // Per-app blocking: recompute shields based on which apps exceeded
        recomputeBlockingAfterLimitChange()
    }
    
    private func applyScreenTimeBlocking() {
        // Recompute per-app shields based on current selection and usage
        recomputeBlockingAfterLimitChange()
    }
    
    private func secondsUntilMidnight(from date: Date) -> TimeInterval {
        let startOfNextDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        return startOfNextDay.timeIntervalSince(date)
    }
    
    private func allLimitedTokens() -> [ApplicationToken] {
        Array(ScreenTimeManager.shared.selectedApps.applicationTokens)
    }

    private func dayPassDonationAmount() -> Double {
        let amount: Double = 0.99
        let net = amount * 0.85 // 15% Apple fee
        return net * 0.15 // 15% of net revenue to charity
    }

    /// Public wrapper to re-apply blocking immediately based on current selection
    func refreshBlockingNow() {
        applyScreenTimeBlocking()
    }

    /// Update local state based on the event data received from the extension.
    func handleLimitEvent(tokens: [ApplicationToken], eventName: String) {
        // Update usage to end-of-limit and recompute shields
        recentlyBlockedTokens = tokens
        for token in tokens {
            if let limit = getCurrentLimit(for: token) {
                let remaining = max(0, limit - todayUsage.usageForApp(token))
                if remaining > 0 {
                    todayUsage.addUsage(for: token, duration: remaining)
                }
            }
        }
        saveTodayUsage()
        recomputeBlockingAfterLimitChange()
        print("📥 Processed limit event \(eventName) for \(tokens.count) apps")
    }
    
    // MARK: - Utility Methods
    

    private func snapshot(from limits: DailyLimits) -> SharedSettings.StoredDailyLimits {
        SharedSettings.StoredDailyLimits(date: limits.date, appSeconds: limits.appLimits, isActive: limits.isActive)
    }

    private func snapshot(from usage: AppUsageDay) -> SharedSettings.StoredUsage {
        SharedSettings.StoredUsage(date: usage.date, appSeconds: usage.appUsage)
    }

    private func convert(_ snapshot: SharedSettings.StoredDailyLimits) -> DailyLimits {
        DailyLimits(date: snapshot.date, appLimits: sanitizeAppLimits(snapshot.appSeconds), isActive: snapshot.isActive)
    }

    private func convert(_ usage: SharedSettings.StoredUsage) -> AppUsageDay {
        var day = AppUsageDay(date: usage.date)
        day.appUsage = sanitizeAppLimits(usage.appSeconds)
        return day
    }

    private func sanitizeAppLimits<T>(_ raw: [String: T]) -> [String: T] {
        var sanitized: [String: T] = [:]
        for (key, value) in raw where Data(base64Encoded: key) != nil {
            sanitized[key] = value
        }
        return sanitized
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#if DEBUG
extension DailyLimitsManager {
    /// Debug helper to instantly mark all selected apps as having exceeded their limits.
    func debugForceBlockSelectedApps() {
        let tokens = ScreenTimeManager.shared.selectedApps.applicationTokens
        guard !tokens.isEmpty else {
            print("🛠️ DEBUG: No selected apps to force block")
            return
        }

        for token in tokens {
            var limit = getCurrentLimit(for: token)
            if limit == nil {
                limit = 60 // default 1 minute if none configured
                currentLimits.setLimit(for: token, limit: limit!)
                pendingLimits.setLimit(for: token, limit: limit!)
            }
            todayUsage.addUsage(for: token, duration: limit ?? 60)
        }

        saveCurrentLimits()
        savePendingLimits()
        saveTodayUsage()
        recomputeBlockingAfterLimitChange()
        recentlyBlockedTokens = Array(tokens)
        print("🛠️ DEBUG: Forced block for \(tokens.count) app(s)")
    }
}
#endif
