import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var dailyLimitMinutes: Int = 120 // Default 2 hours
    @Published var isMonitoring = false
    @Published var hasReachedLimit = false
    @Published var authorizationError: String?
    
    // Last known reason we refreshed the monitoring schedule (for debugging)
    private(set) var lastRefreshReason: String = "init"
    
    // Debug verbosity controls
    private let enableMonitoringHeartbeatLogs = false
    private var cancellables = Set<AnyCancellable>()
    private var blockListSubscription: AnyCancellable?
    private var manualTimeBlockWorkItems: [String: DispatchWorkItem] = [:]
    
    // Check if running on simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    init() {
        selectedApps = BlockListManager.shared.selection
        updateAuthorizationStatus()
        loadSettings()
        print("🏗️ ScreenTimeManager initialized. selectedApps count: \(selectedApps.applicationTokens.count)")
        print("🏗️ Current authorization status: \(authorizationStatus)")
        print("🏗️ Running on simulator: \(isSimulator)")
        NotificationManager.shared.requestAuthorizationIfNeeded()
        // Re-check shortly after launch; sometimes the first read returns a stale cache
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateAuthorizationStatus()
        }
#if canImport(UIKit)
        // Keep status fresh when app returns to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.updateAuthorizationStatus() }
            .store(in: &cancellables)
#endif
        observeBlockList()
        cleanupExpiredTimeBlocks()
        enforceActiveTimeBlocksNow()
        // Avoid accessing DailyLimitsManager during our own initialization to prevent circular init.
        DispatchQueue.main.async { [weak self] in
            self?.debugState(tag: "post-init")
        }
    }
    
    // MARK: - Authorization Methods
    func requestAuthorization() async throws {
        print("🔐 Starting authorization request...")
        print("🔐 Current status before request: \(authorizationStatus)")
        print("🔐 Running on simulator: \(isSimulator)")
        
        // Check if we can access the authorization center
        let center = AuthorizationCenter.shared
        print("🔐 AuthorizationCenter accessible: true")
        
        do {
            print("🔐 Calling requestAuthorization for .individual...")
            try await center.requestAuthorization(for: .individual)
            
            await MainActor.run {
                updateAuthorizationStatus()
                print("✅ Screen Time authorization granted")
                print("✅ New status: \(authorizationStatus)")
            }
        } catch {
            await MainActor.run {
                authorizationError = error.localizedDescription
                print("❌ Screen Time authorization failed: \(error)")
                
                // Enhanced error analysis
                if let nsError = error as NSError? {
                    print("🔍 Error Domain: \(nsError.domain)")
                    print("🔍 Error Code: \(nsError.code)")
                    print("🔍 Error Description: \(nsError.localizedDescription)")
                    
                    let userInfo = nsError.userInfo
                    print("🔍 User Info: \(userInfo)")
                    
                    if let debugDescription = userInfo["NSDebugDescription"] as? String {
                        print("🔍 Debug Description: \(debugDescription)")
                    }
                    
                    // Specific handling for sandbox restriction
                    if nsError.code == 4099 {
                        print("🚨 SANDBOX RESTRICTION DETECTED!")
                        print("🚨 This usually means:")
                        print("   - Entitlements not properly configured")
                        print("   - Provisioning profile doesn't include Family Controls")
                        print("   - App not properly signed with correct capabilities")
                        print("   - iOS version compatibility issue")
                        
                        if isSimulator {
                            print("🚨 Note: This error on simulator is expected for Device Activity")
                            print("🚨 Family Controls authorization should still work on simulator")
                        }
                    }
                }
            }
            throw error
        }
    }
    
    private func updateAuthorizationStatus() {
        let oldStatus = authorizationStatus
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        print("🔄 Authorization status updated: \(oldStatus) -> \(authorizationStatus)")

        guard authorizationStatus == .approved, oldStatus != .approved else { return }

        // Kick off monitoring and blocking now that authorization is in place.
        refreshMonitoringSchedule(reason: "authorization granted")
        DailyLimitsManager.shared.refreshBlockingNow()
    }
    
    var isAuthorized: Bool {
        return authorizationStatus == .approved
    }
    
    func updateSelectedApps(_ selection: FamilyActivitySelection, reason: String = "selection updated") {
        BlockListManager.shared.update(selection: selection, reason: reason)
    }
    
    // MARK: - Screen Time Operations
    func startMonitoring() throws {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }
        try configureDailyMonitoring()
    }

    func stopMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])
        isMonitoring = false
        print("⏹️ Stopped monitoring device activity")
        debugState(tag: "stopMonitoring")
    }
    
    func blockApps() {
        guard isAuthorized else {
            print("❌ Cannot block apps: not authorized")
            return
        }
        DailyLimitsManager.shared.refreshBlockingNow()
    }
    
    func unblockApps() {
        let store = ManagedSettingsStore()
        store.clearAllSettings()
        print("🔓 Removed all app restrictions")
        debugState(tag: "unblockApps")
    }
    
    func temporaryUnlock(tokens: [ApplicationToken], duration: TimeInterval) {
        guard !tokens.isEmpty else { return }
        SharedSettings.applyCurrentShieldState(reason: "temporary unlock granted")
        SharedSettings.scheduleTemporaryUnlockExpiryMonitoring()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            _ = SharedSettings.activeTemporaryUnlocks()
            SharedSettings.applyCurrentShieldState(reason: "temporary unlock foreground expiry")
            SharedSettings.scheduleTemporaryUnlockExpiryMonitoring()
            print("🔒 Temporary unlock expired for \(tokens.count) app(s)")
        }
    }

    func startReviewerBlock(duration: TimeInterval = 120) {
        guard isAuthorized else {
            print("⚠️ Cannot start reviewer block: Screen Time permissions missing")
            return
        }
        let tokens = selectedApps.applicationTokens
        guard !tokens.isEmpty else {
            print("⚠️ Reviewer block aborted: no apps in block list")
            return
        }
        let store = ManagedSettingsStore()
        var shielded = store.shield.applications ?? []
        let tokenSet = Set(tokens)
        shielded.formUnion(tokenSet)
        store.shield.applications = shielded
        SharedSettings.setBlockingState(true)
        print("🧪 Reviewer block started for \(tokenSet.count) app(s) for \(Int(duration)) seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            var current = store.shield.applications ?? []
            current.subtract(tokenSet)
            store.shield.applications = current
            if current.isEmpty {
                SharedSettings.setBlockingState(false)
            }
            print("🧪 Reviewer block ended")
        }
    }
    
    func updateDailyLimit(_ minutes: Int) {
        dailyLimitMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: "dailyLimitMinutes")
        
        if isMonitoring {
            stopMonitoring()
            try? startMonitoring()
        }
        NotificationManager.shared.postSettingsUpdatedNotification()
    }
    
    func refreshMonitoringSchedule(reason: String = "manual") {
        print("⏱️ Refreshing monitoring schedule (\(reason))")
        lastRefreshReason = reason
        do {
            try configureDailyMonitoring()
            try configureTimeBlockMonitoring()
            enforceActiveTimeBlocksNow()
        } catch {
            print("❌ Failed to refresh monitoring: \(error)")
        }
        debugState(tag: "refreshMonitoringSchedule")
    }

    private func loadSettings() {
        dailyLimitMinutes = UserDefaults.standard.integer(forKey: "dailyLimitMinutes")
        if dailyLimitMinutes == 0 {
            dailyLimitMinutes = 120 // Default 2 hours
        }
    }

    private func observeBlockList() {
        blockListSubscription = BlockListManager.shared.$selection
            .receive(on: RunLoop.main)
            .sink { [weak self] newSelection in
                guard let self else { return }
                self.selectedApps = newSelection
                self.refreshMonitoringSchedule(reason: "block list updated")
                self.debugState(tag: "block list update")
            }
    }

    func enforceActiveTimeBlocksNow() {
        syncTimeBlockStates()
    }

    private func configureDailyMonitoring() throws {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }

        let tokens = selectedApps.applicationTokens
        guard !tokens.isEmpty else {
            stopMonitoring()
            print("ℹ️ No selected apps to monitor")
            return
        }

        let limitsManager = DailyLimitsManager.shared
        let activeLimits = limitsManager.currentLimits.appLimits

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        var eventMap: [String: [String]] = [:] // eventName -> [tokenId]
        for (index, entry) in activeLimits.sorted(by: { $0.key < $1.key }).enumerated() {
            guard let appToken = ApplicationToken(identifier: entry.key),
                  tokens.contains(appToken) else {
                continue
            }

            let seconds = max(1, Int(entry.value))
            let eventName = DeviceActivityEvent.Name("limit_\(index)")
            events[eventName] = DeviceActivityEvent(
                applications: [appToken],
                threshold: DateComponents(second: seconds)
            )
            eventMap[eventName.rawValue] = [appToken.identifier]
            if index < 5 { // log first few for brevity
                print("🧭 Event \(eventName.rawValue): app=\(appToken.identifier.prefix(8))… threshold=\(seconds)s")
            }
        }

        guard !events.isEmpty else {
            stopMonitoring()
            print("ℹ️ No active limits to monitor")
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])

        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
            isMonitoring = true
            print("📊 Started monitoring device activity with \(events.count) events")
            SharedSettings.persistEventTokenMap(eventMap)
            debugState(tag: "configureDailyMonitoring.start")
        } catch {
            isMonitoring = false
            print("❌ Failed to start monitoring with events: \(error)")
            throw ScreenTimeError.monitoringFailed
        }
    }

    private func configureTimeBlockMonitoring() throws {
        guard isAuthorized else { throw ScreenTimeError.notAuthorized }
        let blocks = SharedSettings.loadTimeBlocks().filter { $0.enabled && $0.isSameDayValid() && $0.durationSeconds() >= 3600 }

        let center = DeviceActivityCenter()
        // Stop previously monitored timeblock names to avoid stale schedules
        let prev = SharedSettings.loadPreviouslyMonitoredTimeBlockNames()
        if !prev.isEmpty {
            let names = prev.map { DeviceActivityName($0) }
            center.stopMonitoring(names)
        }

        var startedNames: [String] = []
        for block in blocks {
            let name = SharedSettings.deviceActivityName(for: block)
            let schedule = DeviceActivitySchedule(
                intervalStart: block.startComponents(),
                intervalEnd: block.endComponents(),
                repeats: true
            )
            do {
                try center.startMonitoring(name, during: schedule)
                startedNames.append(name.rawValue)
                print("⏱️ TimeBlock scheduled: \(block.name) [\(block.startHour):\(String(format: "%02d", block.startMinute))–\(block.endHour):\(String(format: "%02d", block.endMinute))]")
            } catch {
                print("❌ Failed to start timeblock \(block.name): \(error)")
            }
        }
        SharedSettings.saveMonitoredTimeBlockNames(startedNames)
    }

    private func cleanupExpiredTimeBlocks() {
        let now = Date().timeIntervalSince1970
        for state in SharedSettings.activeTimeBlockStates() where state.endsAt <= now {
            clearTimeBlock(blockId: state.id)
        }
    }

    private func syncTimeBlockStates() {
        cleanupExpiredTimeBlocks()
        let now = Date()
        let blocks = SharedSettings.loadTimeBlocks()
        let blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })

        for state in SharedSettings.activeTimeBlockStates() {
            guard let block = blockMap[state.id] else {
                clearTimeBlock(blockId: state.id)
                continue
            }
            if !block.enabled || !block.isSameDayValid() || !block.isActive(on: now) {
                clearTimeBlock(blockId: state.id)
            }
        }

        let refreshedStates = SharedSettings.activeTimeBlockStates().filter { $0.endsAt > now.timeIntervalSince1970 }
        let activeIds = Set(refreshedStates.map { $0.id })
        for block in blocks where block.enabled && block.isSameDayValid() && block.isActive(on: now) {
            if !activeIds.contains(block.id) {
                applyManualTimeBlock(block)
            }
        }
    }

    private func applyManualTimeBlock(_ block: SharedSettings.TimeBlock) {
        guard isAuthorized else { return }
        let tokens = BlockListManager.shared.selection.applicationTokens
        guard !tokens.isEmpty else {
            print("⚠️ Time Block \(block.name) active, but no apps are selected to shield")
            return
        }

        SharedSettings.setActiveTokens(Array(tokens), forBlockId: block.id)
        let remaining = block.remainingSeconds()
        guard remaining > 0 else { return }
        let endsAt = Date().addingTimeInterval(remaining).timeIntervalSince1970
        let state = SharedSettings.ActiveTimeBlockState(id: block.id, name: block.name, endsAt: endsAt)
        SharedSettings.setActiveTimeBlockState(state, forBlockId: block.id)
        let shielded = SharedSettings.applyCurrentShieldState(reason: "manual time block active")

        manualTimeBlockWorkItems[block.id]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.clearTimeBlock(blockId: block.id)
        }
        manualTimeBlockWorkItems[block.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
        print("🧱 Manually enforced Time Block \(block.name) for \(tokens.count) intended app(s); shielded now=\(shielded.count)")
    }

    private func clearTimeBlock(blockId: String) {
        manualTimeBlockWorkItems[blockId]?.cancel()
        manualTimeBlockWorkItems.removeValue(forKey: blockId)

        let tokensToRemove = Set(SharedSettings.activeTokens(forBlockId: blockId))
        SharedSettings.clearActiveTokens(forBlockId: blockId)
        SharedSettings.removeActiveTimeBlockState(forBlockId: blockId)
        let shielded = SharedSettings.applyCurrentShieldState(reason: "time block cleared")
        print("🧱 Cleared Time Block \(blockId) ledger for \(tokensToRemove.count) intended app(s); shielded now=\(shielded.count)")
    }
    
    // MARK: - Debug Methods
    func checkAuthorizationStatus() {
        updateAuthorizationStatus()
    }

    @discardableResult
    func refreshAuthorizationStatus() -> AuthorizationStatus {
        updateAuthorizationStatus()
        return authorizationStatus
    }
    
    func resetAuthorization() {
        authorizationError = nil
        updateAuthorizationStatus()
        print("🔄 Authorization status reset and refreshed: \(authorizationStatus)")
    }
    
    func forceRefreshStatus() {
        print("🔄 Force refreshing authorization status...")
        let oldStatus = authorizationStatus
        updateAuthorizationStatus()
        print("🔄 Status changed from \(oldStatus) to \(authorizationStatus)")
    }
    
    // MARK: - Debug Methods
    func debugCapabilities() {
        print("🔍 === CAPABILITIES DEBUG ===")
        print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("🔍 Team ID: \(Bundle.main.infoDictionary?["CFBundleTeamIdentifier"] as? String ?? "Unknown")")
        print("🔍 Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        print("🔍 Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
        print("🔍 Running on simulator: \(isSimulator)")
        
        // Check if entitlements are accessible
        if let entitlementsPath = Bundle.main.path(forResource: "MindLock", ofType: "entitlements") {
            print("🔍 Entitlements file found at: \(entitlementsPath)")
        } else {
            print("🔍 ❌ Entitlements file NOT found!")
        }
        
        print("🔍 === END CAPABILITIES DEBUG ===")
    }
    
    // MARK: - Testing Methods
    
    /// Start monitoring for testing purposes using actual configured limits
    func startOneMinuteTest() async throws {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }
        
        guard !selectedApps.applicationTokens.isEmpty else {
            throw ScreenTimeError.monitoringFailed
        }
        
        // Get the actual limits from DailyLimitsManager
        let limitsManager = DailyLimitsManager.shared
        var testLimits: [ApplicationToken: TimeInterval] = [:]
        
        print("🔍 Checking limits in DailyLimitsManager...")
        print("🔍 Selected apps count: \(selectedApps.applicationTokens.count)")
        
        for token in selectedApps.applicationTokens {
            print("🔍 Checking limit for token: \(token)")
            if let limit = limitsManager.getCurrentLimit(for: token) {
                let testLimit = min(limit, 60) // Cap at 1 minute for testing
                testLimits[token] = testLimit
                print("🧪 Test limit for app: \(formatTime(testLimit)) (original: \(formatTime(limit)))")
            } else if let pendingLimit = limitsManager.getPendingLimit(for: token) {
                let testLimit = min(pendingLimit, 60) // Cap at 1 minute for testing
                testLimits[token] = testLimit
                print("🧪 Test limit for app: \(formatTime(testLimit)) (from pending: \(formatTime(pendingLimit)))")
            } else {
                testLimits[token] = 60
                print("🧪 Default test limit for app: 1 minute")
                print("⚠️ No limit found in DailyLimitsManager for token: \(token)")
            }
        }
        
        // Create a monitoring schedule that covers a longer period
        let now = Date()
        let endTime = now.addingTimeInterval(30 * 60) // 30-minute window to satisfy API minimum
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime)
        
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
        
        // Create a unique test activity name to avoid conflicts
        let testActivity = DeviceActivityName("MindLockTest")
        
        // Create test events with actual configured limits
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let orderedLimits = testLimits.sorted { $0.key.identifier < $1.key.identifier }
        for (index, entry) in orderedLimits.enumerated() {
            let token = entry.key
            let limit = entry.value
            let eventName = DeviceActivityEvent.Name("testLimit_\(index)")
            events[eventName] = DeviceActivityEvent(
                applications: [token],
                threshold: DateComponents(second: Int(limit))
            )
        }
        
        let center = DeviceActivityCenter()
        do {
            // Stop any existing monitoring first
            center.stopMonitoring([.daily, testActivity])
            
            // Add a small delay to ensure clean restart
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            try center.startMonitoring(testActivity, during: schedule, events: events)
            isMonitoring = true
            print("🧪 Started test monitoring with actual configured limits")
            print("🧪 Schedule: \(now) to \(endTime) (30-minute window)")
            print("🧪 Apps being monitored: \(selectedApps.applicationTokens.count)")
            print("🧪 Test activity name: \(testActivity)")
            print("🧪 Events created: \(events.count)")
            
            // Check if monitoring is active
            let activities = center.activities
            print("🧪 Currently monitoring activities: \(activities)")
            
            // Start periodic monitoring confirmation
            startMonitoringConfirmation()
            
            // Debug: Check if extension is accessible
            checkExtensionAccessibility()
            debugState(tag: "startOneMinuteTest.start")
        } catch {
            print("❌ Failed to start test monitoring: \(error)")
            throw ScreenTimeError.monitoringFailed
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
    
    private func startMonitoringConfirmation() {
        #if DEBUG
        guard enableMonitoringHeartbeatLogs else { return }
        // Confirm monitoring is active every 30 seconds (debug only)
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            let center = DeviceActivityCenter()
            let activities = center.activities
            print("📊 Monitoring status check - Active activities: \(activities)")
            print("📊 Current time: \(Date())")
            
            // Check if our test activity is still being monitored
            let testActivity = DeviceActivityName("MindLockTest")
            if activities.contains(testActivity) {
                print("✅ Test monitoring is still active")
            } else {
                print("❌ Test monitoring has stopped")
            }
        }
        #endif
    }
    
    private func checkExtensionAccessibility() {
        print("🔍 Checking extension accessibility...")
        
        // Check if we can access the extension bundle
        let bundleIdentifier = SharedSettings.extensionBundleIdentifier(fallback: "com.lucaszambranonavia.mindlock.monitor")
        if let extensionBundle = Bundle(identifier: bundleIdentifier) {
            print("✅ Extension bundle accessible: \(extensionBundle.bundleIdentifier ?? "Unknown")")
        } else {
            print("❌ Extension bundle NOT accessible")
        }
        
        // Check if the extension is listed in available extensions
        let center = DeviceActivityCenter()
        print("🔍 DeviceActivityCenter available: \(center)")
        print("🔍 Current activities: \(center.activities)")
        
        // Try to create a simple monitoring event to see if extension responds
        let testEvent = DeviceActivityEvent(
            applications: selectedApps.applicationTokens,
            threshold: DateComponents(second: 1)
        )
        print("🔍 Test event created: \(testEvent)")
        
        // Check if we can access the extension's entitlements
        if let entitlementsPath = Bundle.main.path(forResource: "MindLockMonitor", ofType: "entitlements") {
            print("✅ Extension entitlements found at: \(entitlementsPath)")
        } else {
            print("❌ Extension entitlements NOT found")
        }

        // Read extension heartbeat written via app group to confirm the monitor process is alive
        if let ts = SharedSettings.sharedDefaults?.object(forKey: "monitor.heartbeat") as? Double {
            let date = Date(timeIntervalSince1970: ts)
            print("✅ Monitor heartbeat detected at: \(date)")
        } else {
            print("ℹ️ No monitor heartbeat yet (will appear after interval start or first event)")
        }
    }
}

// MARK: - Error Types
enum ScreenTimeError: LocalizedError {
    case notAuthorized
    case monitoringFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time access not authorized"
        case .monitoringFailed:
            return "Failed to start monitoring"
        }
    }
}

extension DeviceActivityName {
    static let daily = Self("daily")
} 

// MARK: - Debug Helpers
extension ScreenTimeManager {
    private func summarizeSelectedIDs(maxCount: Int = 5) -> String {
        let ids = selectedApps.applicationTokens.map { $0.identifier }
        if ids.isEmpty { return "[]" }
        let head = ids.prefix(maxCount).map { String($0.prefix(8)) + "…" }
        let more = ids.count > maxCount ? ", +\(ids.count - maxCount) more" : ""
        return "[" + head.joined(separator: ", ") + "]" + more
    }

    private func limitsSummary() -> String {
        let lm = DailyLimitsManager.shared
        let cur = lm.currentLimits.appLimits
        let pen = lm.pendingLimits.appLimits
        let sel = Set(selectedApps.applicationTokens.map { $0.identifier })
        let curCount = cur.filter { sel.contains($0.key) }.count
        let penCount = pen.filter { sel.contains($0.key) }.count
        return "current=\(curCount), pending=\(penCount)"
    }

    func debugState(tag: String) {
        let lm = DailyLimitsManager.shared
        let activities = DeviceActivityCenter().activities
        print("🔎 ST State [\(tag)]\n  auth=\(authorizationStatus) | monitoring=\(isMonitoring) | lastRefresh=\(lastRefreshReason)\n  selectedApps=\(selectedApps.applicationTokens.count) \(summarizeSelectedIDs())\n  limits(\(limitsSummary())) | blocking=\(lm.isBlocking) blockedCount=\(lm.recentlyBlockedTokens.count)\n  activities=\(activities)")
    }
}
