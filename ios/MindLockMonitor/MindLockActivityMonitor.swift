import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
}

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

        // Treat the start of daily monitoring as a new day and clear previous shields.
        if activity == DeviceActivityName("MindLockDemo") {
            // demo: no-op
        } else if activity == .daily {
            _ = SharedSettings.performMidnightRollover(referenceDate: Date())
            let store = ManagedSettingsStore()
            store.shield.applications = [] as Set<ApplicationToken>
            SharedSettings.setBlockingState(false)
            SharedSettings.clearLimitEvent()
            print("🌅 Cleared shields and refreshed limits for new interval")
        } else if activity.rawValue.hasPrefix("tb_") {
            // Time Block start: if the block is active today, apply shields for selected apps (respect unlocks)
            let blockId = String(activity.rawValue.dropFirst(3))
            let now = Date()
            guard let block = SharedSettings.loadTimeBlocks().first(where: { $0.id == blockId }), block.isActive(on: now) else {
                print("ℹ️ TimeBlock \(activity.rawValue) not active today; skipping")
                return
            }
            var tokenSet = SharedSettings.storedApplicationTokens()
            if tokenSet.isEmpty {
                print("ℹ️ No selected apps for TimeBlock")
                return
            }
            let suppress = SharedSettings.activeTemporaryUnlocks()
            tokenSet = Set(tokenSet.filter { suppress[SharedSettings.tokenKey($0)] == nil })
            let store = ManagedSettingsStore()
            var shielded = store.shield.applications ?? []
            shielded.formUnion(tokenSet)
            store.shield.applications = shielded
            SharedSettings.setActiveTokens(Array(tokenSet), forBlockId: blockId)
            if let endDate = Self.endDate(for: block, reference: now) {
                let state = SharedSettings.ActiveTimeBlockState(
                    id: block.id,
                    name: block.name,
                    endsAt: endDate.timeIntervalSince1970
                )
                SharedSettings.setActiveTimeBlockState(state, forBlockId: blockId)
            }
            print("🧱 TimeBlock applied shields for \(tokenSet.count) app(s)")
        }

        SharedSettings.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "monitor.heartbeat")
        SharedSettings.sharedDefaults?.synchronize()
    }

    public override func intervalDidEnd(for activity: DeviceActivityName) {
        print("🔔 Interval ended for activity: \(activity)")
        print("🔔 Current time: \(Date())")
        print("🔔 Is this a test activity? \(activity == DeviceActivityName("MindLockTest"))")
        // Called at end of scheduled monitoring interval
        if activity.rawValue.hasPrefix("tb_") {
            let blockId = String(activity.rawValue.dropFirst(3))
            let added = SharedSettings.activeTokens(forBlockId: blockId)
            SharedSettings.clearActiveTokens(forBlockId: blockId)
            SharedSettings.removeActiveTimeBlockState(forBlockId: blockId)
            guard !added.isEmpty else { return }
            let store = ManagedSettingsStore()
            var shielded = store.shield.applications ?? []
            shielded.subtract(Set(added))
            store.shield.applications = shielded
            print("🧱 TimeBlock removed shields for \(added.count) app(s)")
        }
    }

    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        print("🔔 Event threshold reached: \(event) for activity: \(activity)")
        print("🔔 Current time: \(Date())")
        print("🔔 Event name: \(event.rawValue)")
        print("🔔 Activity name: \(activity)")
        print("🔔 Is this a test activity? \(activity == DeviceActivityName("MindLockTest"))")
        print("🔔 Extension process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("🔔 Extension bundle: \(Bundle.main.bundleIdentifier ?? "Unknown")")

        defer {
            SharedSettings.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "monitor.heartbeat")
            SharedSettings.sharedDefaults?.synchronize()
        }

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

        let activeSuppressions = SharedSettings.activeTemporaryUnlocks()
        let tokensToShield = Set(tokens.filter { activeSuppressions[SharedSettings.tokenKey($0)] == nil })
        if tokensToShield.isEmpty {
            if let soonestExpiry = activeSuppressions.values.min() {
                print("⏳ Limit reached during an active unlock (expires \(soonestExpiry)). Skipping shield update.")
            } else {
                print("⏳ Limit reached but temporary unlock state prevented shielding.")
            }
            return
        }

        SharedSettings.storeLimitEvent(name: event.rawValue, blockedTokens: Array(tokensToShield))

        let store = ManagedSettingsStore()
        var shielded = store.shield.applications ?? []
        shielded.formUnion(tokensToShield)
        store.shield.applications = shielded
        print("🔒 Blocked \(tokensToShield.count) application(s) due to limit reached (per-app)")
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
    private static func endDate(for block: SharedSettings.TimeBlock, reference now: Date) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = block.endHour
        comps.minute = block.endMinute
        return Calendar.current.date(from: comps)
    }
}
