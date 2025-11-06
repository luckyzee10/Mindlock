import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

public class MindLockActivityMonitor: DeviceActivityMonitor {
    public override init() {
        super.init()
        print("🔔 MindLockActivityMonitor initialized")
        print("🔔 Extension bundle: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("🔔 Extension entitlements: \(Bundle.main.path(forResource: "MindLockMonitor", ofType: "entitlements") ?? "Not found")")
    }

    public override func intervalDidStart(for activity: DeviceActivityName) {
        print("🔔 Interval started for activity: \(activity)")
        print("🔔 Current time: \(Date())")
        print("🔔 Is this a test activity? \(activity == DeviceActivityName("MindLockTest"))")
        // Called at start of scheduled monitoring interval

        // Treat the start of any non-demo interval as a new day and clear previous shields.
        if activity != DeviceActivityName("MindLockDemo") {
            _ = SharedSettings.performMidnightRollover(referenceDate: Date())
            let store = ManagedSettingsStore()
            store.shield.applications = []
            SharedSettings.setBlockingState(false)
            SharedSettings.clearLimitEvent()
            print("🌅 Cleared shields and refreshed limits for new interval")
        }

        SharedSettings.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "monitor.heartbeat")
        SharedSettings.sharedDefaults?.synchronize()
    }

    public override func intervalDidEnd(for activity: DeviceActivityName) {
        print("🔔 Interval ended for activity: \(activity)")
        print("🔔 Current time: \(Date())")
        print("🔔 Is this a test activity? \(activity == DeviceActivityName("MindLockTest"))")
        // Called at end of scheduled monitoring interval
    }

    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        print("🔔 Event threshold reached: \(event) for activity: \(activity)")
        print("🔔 Current time: \(Date())")
        print("🔔 Event name: \(event.rawValue)")
        print("🔔 Activity name: \(activity)")
        print("🔔 Is this a test activity? \(activity == DeviceActivityName("MindLockTest"))")
        print("🔔 Extension process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("🔔 Extension bundle: \(Bundle.main.bundleIdentifier ?? "Unknown")")

        if activity == DeviceActivityName("MindLockDemo") || event.rawValue.hasPrefix("demo_") {
            print("🔕 Demo event triggered; skipping shield application.")
            return
        }
        
        // Resolve which token(s) this specific event represents; fallback to all selected if missing
        var tokens = SharedSettings.tokensForEvent(event.rawValue)
        if tokens.isEmpty {
            if let inferred = inferToken(fromEventName: event.rawValue) {
                tokens.insert(inferred)
                print("⚠️ Event-token map missing; inferred token \(inferred.identifier.prefix(8))… from event name")
            } else {
                tokens = SharedSettings.storedApplicationTokens()
                print("⚠️ Event-token map missing; falling back to all selected apps")
            }
        }
        guard !tokens.isEmpty else {
            print("⚠️ No selected apps found in shared defaults")
            return
        }

        SharedSettings.storeLimitEvent(name: event.rawValue, blockedTokens: Array(tokens))

        let activeSuppressions = SharedSettings.activeTemporaryUnlocks()
        let tokensToShield = tokens.filter { activeSuppressions[$0.identifier] == nil }

        if tokensToShield.isEmpty {
            print("⏳ Limit reached but app is in temporary unlock window; skipping shield update")
        } else {
            let store = ManagedSettingsStore()
            let existing = store.shield.applications ?? []
            store.shield.applications = existing.union(tokensToShield)
            print("🔒 Blocked \(tokensToShield.count) application(s) due to limit reached (per-app)")
        }

        SharedSettings.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "monitor.heartbeat")
        SharedSettings.sharedDefaults?.synchronize()
    }
    
    public override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        print("⚠️ Event will reach threshold warning: \(event) for activity: \(activity)")
        // Could show a warning notification here
    }

    private func inferToken(fromEventName name: String) -> ApplicationToken? {
        guard name.hasPrefix("limit_"),
              let indexComponent = name.split(separator: "_").last,
              let index = Int(indexComponent),
              let currentLimits = SharedSettings.loadCurrentLimits()
        else {
            return nil
        }

        let sortedKeys = currentLimits.appSeconds.keys.sorted()
        guard index >= 0, index < sortedKeys.count else { return nil }
        return ApplicationToken(identifier: sortedKeys[index])
    }
}
