import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Analytics Summary Type (shared across app + extensions)
struct AnalyticsDaySummary: Codable {
    var date: String // YYYY-MM-DD
    var totalScreenTime: TimeInterval
    var productiveSeconds: TimeInterval
    var distractingSeconds: TimeInterval
    var hourly: [HourlyBucket] // 24 buckets
    var perApp: [PerAppUsage]
    var totalDonated: Double?
    var blockCount: Int?
    var charityBreakdown: [CharityContribution]?

    struct HourlyBucket: Codable { var hour: Int; var productive: TimeInterval; var distracting: TimeInterval }
    struct PerAppUsage: Codable {
        var tokenId: String
        var seconds: TimeInterval
        var displayName: String?
        var bundleIdentifier: String?
        var hasToken: Bool?
        var isDistracting: Bool?
    }
    struct CharityContribution: Codable {
        var charityId: String
        var displayName: String?
        var amount: Double
    }
}

/// Shared constants and helpers for communicating between the main app and the extension.
enum SharedSettings {
    struct CharityAggregate: Codable, Identifiable {
        let id: String
        var name: String
        var amount: Double
    }

    struct UnlockStatsRecord: Codable, Identifiable {
        let id: String
        var freeUnlocks: Int
        var dayPassUnlocks: Int
        var freeMinutes: Double
        var dayPassMinutes: Double

        var totalUnlocks: Int { freeUnlocks + dayPassUnlocks }
        var totalMinutes: Double { freeMinutes + dayPassMinutes }
    }

    enum UnlockEventKind {
        case free(minutes: Double)
        case dayPass(minutes: Double)
    }

    static let appGroupIdentifier = "group.com.YLUUT5U99U.mindlock"
    static let extensionBundleIdentifierKey = "MindLockMonitorBundleIdentifier"
    static let limitEventNotificationName = "com.YLUUT5U99U.mindlock.limitEvent"
    static let analyticsUpdatedNotification = Notification.Name("MindLockAnalyticsUpdated")
    
    private enum Keys {
        static let selectionData = "shared.selectionData"
        static let lastEventName = "shared.lastEventName"
        static let lastBlockedTokens = "shared.lastBlockedTokens"
        static let isBlocking = "shared.isBlocking"
        static let eventTokenMap = "shared.eventTokenMap" // [eventName: [tokenId]]
        static func analyticsDayKey(_ day: String) -> String { "analytics.summary.\(day)" }
        static let analyticsLastWrite = "shared.analytics.lastWrite"
        static let currentLimits = "shared.limits.current"
        static let pendingLimits = "shared.limits.pending"
        static let todayUsage = "shared.usage.today"
        static let lastRollover = "shared.rollover.timestamp"
        static let unlockSuppressions = "shared.unlock.suppressions"
        static let profileTotalDonation = "profile.totalDonation"
        static let profileCharityTotals = "profile.charityTotals"
        static let profileUnlockStats = "profile.unlock.stats"
    }
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Shared Daily Limits Storage
    struct StoredDailyLimits: Codable {
        var date: Date
        var appSeconds: [String: TimeInterval]
        var isActive: Bool
    }

    struct StoredUsage: Codable {
        var date: Date
        var appSeconds: [String: TimeInterval]
    }

    private struct StoredEventTokenMap: Codable {
        var events: [String: [String]]
    }

    private struct StoredTemporaryUnlocks: Codable {
        var suppressions: [String: TimeInterval]
    }

    static func storeCurrentLimits(_ snapshot: StoredDailyLimits) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: Keys.currentLimits)
    }

    static func storePendingLimits(_ snapshot: StoredDailyLimits) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: Keys.pendingLimits)
    }

    static func storeTodayUsage(_ usage: StoredUsage) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        sharedDefaults?.set(data, forKey: Keys.todayUsage)
    }

    static func loadCurrentLimits() -> StoredDailyLimits? {
        guard let data = sharedDefaults?.data(forKey: Keys.currentLimits),
              let snapshot = try? JSONDecoder().decode(StoredDailyLimits.self, from: data) else {
            return nil
        }
        return snapshot
    }

    static func loadPendingLimits() -> StoredDailyLimits? {
        guard let data = sharedDefaults?.data(forKey: Keys.pendingLimits),
              let snapshot = try? JSONDecoder().decode(StoredDailyLimits.self, from: data) else {
            return nil
        }
        return snapshot
    }

    static func loadTodayUsage() -> StoredUsage? {
        guard let data = sharedDefaults?.data(forKey: Keys.todayUsage),
              let usage = try? JSONDecoder().decode(StoredUsage.self, from: data) else {
            return nil
        }
        return usage
    }

    @discardableResult
    static func performMidnightRollover(referenceDate: Date = Date()) -> (current: StoredDailyLimits, pending: StoredDailyLimits, usage: StoredUsage) {
        let today = referenceDate

        let pendingSnapshot = loadPendingLimits() ?? loadCurrentLimits()

        let promotedLimits = pendingSnapshot?.appSeconds ?? [:]

        let newCurrent = StoredDailyLimits(date: today, appSeconds: promotedLimits, isActive: true)
        let newPending = StoredDailyLimits(date: today, appSeconds: promotedLimits, isActive: false)
        let newUsage = StoredUsage(date: today, appSeconds: [:])

        storeCurrentLimits(newCurrent)
        storePendingLimits(newPending)
        storeTodayUsage(newUsage)
        sharedDefaults?.set(today.timeIntervalSince1970, forKey: Keys.lastRollover)

        return (newCurrent, newPending, newUsage)
    }

    /// Persist a mapping from DeviceActivity event names to the app tokens they monitor.
    static func persistEventTokenMap(_ map: [String: [String]]) {
        guard !map.isEmpty else {
            sharedDefaults?.removeObject(forKey: Keys.eventTokenMap)
            return
        }

        let payload = StoredEventTokenMap(events: map)
        if let data = try? JSONEncoder().encode(payload) {
            sharedDefaults?.set(data, forKey: Keys.eventTokenMap)
        } else {
            print("⚠️ Failed to encode event token map; clearing existing value")
            sharedDefaults?.removeObject(forKey: Keys.eventTokenMap)
        }
    }

    /// Resolve which tokens should be blocked for a given event name.
    static func tokensForEvent(_ eventName: String) -> Set<ApplicationToken> {
        if let data = sharedDefaults?.data(forKey: Keys.eventTokenMap) {
            do {
                let decoded = try JSONDecoder().decode(StoredEventTokenMap.self, from: data)
                if let ids = decoded.events[eventName] {
                    let tokens = ids.compactMap { ApplicationToken(identifier: $0) }
                    return Set(tokens)
                }
            } catch {
                print("⚠️ Failed to decode stored event token map: \(error)")
            }
        }

        if let legacy = sharedDefaults?.dictionary(forKey: Keys.eventTokenMap) as? [String: [String]],
           let ids = legacy[eventName] {
            let tokens = ids.compactMap { ApplicationToken(identifier: $0) }
            return Set(tokens)
        }

        return []
    }

    // MARK: - Temporary Unlock Suppressions

    private static func loadTemporaryUnlocks() -> [String: TimeInterval] {
        guard
            let data = sharedDefaults?.data(forKey: Keys.unlockSuppressions),
            let stored = try? JSONDecoder().decode(StoredTemporaryUnlocks.self, from: data)
        else {
            return [:]
        }
        return stored.suppressions
    }

    private static func saveTemporaryUnlocks(_ suppressions: [String: TimeInterval]) {
        guard let defaults = sharedDefaults else { return }
        let payload = StoredTemporaryUnlocks(suppressions: suppressions)
        let encoder = JSONEncoder()
        let data: Data
        if let encoded = try? encoder.encode(payload) {
            data = encoded
        } else {
            print("⚠️ Failed to encode temporary unlocks payload")
            return
        }

        defaults.set(data, forKey: Keys.unlockSuppressions)
    }

    @discardableResult
    static func setTemporaryUnlock(for token: ApplicationToken, until expiry: Date) -> Date {
        return setTemporaryUnlock(for: [token], until: expiry)
    }

    /// Apply the same temporary unlock expiry to a collection of tokens.
    @discardableResult
    static func setTemporaryUnlock(for tokens: [ApplicationToken], until expiry: Date) -> Date {
        guard !tokens.isEmpty else { return expiry }

        var suppressions = loadTemporaryUnlocks()
        let timestamp = expiry.timeIntervalSince1970
        var didChange = false

        for token in tokens {
            let key = tokenKey(token)
            if suppressions[key] != timestamp {
                suppressions[key] = timestamp
                didChange = true
            }
        }

        if didChange {
            saveTemporaryUnlocks(suppressions)
        }

        return expiry
    }

    static func removeTemporaryUnlock(for token: ApplicationToken) {
        var suppressions = loadTemporaryUnlocks()
        if suppressions.removeValue(forKey: tokenKey(token)) != nil {
            saveTemporaryUnlocks(suppressions)
        }
    }

    /// Remove any temporary unlock overrides for the provided tokens.
    static func removeTemporaryUnlocks(for tokens: [ApplicationToken]) {
        guard !tokens.isEmpty else { return }
        var suppressions = loadTemporaryUnlocks()
        var didChange = false

        for token in tokens {
            if suppressions.removeValue(forKey: tokenKey(token)) != nil {
                didChange = true
            }
        }

        if didChange {
            saveTemporaryUnlocks(suppressions)
        }
    }

    /// Returns active suppressions (tokenId -> expiry) and prunes expired entries.
    static func activeTemporaryUnlocks() -> [String: Date] {
        var suppressions = loadTemporaryUnlocks()
        let now = Date().timeIntervalSince1970
        var active: [String: Date] = [:]
        var didChange = false
        for (identifier, timestamp) in suppressions {
            if timestamp > now {
                active[identifier] = Date(timeIntervalSince1970: timestamp)
            } else {
                suppressions.removeValue(forKey: identifier)
                didChange = true
            }
        }
        if didChange {
            saveTemporaryUnlocks(suppressions)
        }
        return active
    }

    static func hasActiveTemporaryUnlock(for token: ApplicationToken) -> Bool {
        return temporaryUnlockExpiry(for: token) != nil
    }

    static func temporaryUnlockExpiry(for token: ApplicationToken) -> Date? {
        var suppressions = loadTemporaryUnlocks()
        let now = Date().timeIntervalSince1970
        guard let timestamp = suppressions[tokenKey(token)] else { return nil }
        if timestamp > now {
            return Date(timeIntervalSince1970: timestamp)
        }
        suppressions.removeValue(forKey: tokenKey(token))
        saveTemporaryUnlocks(suppressions)
        return nil
    }

    // MARK: - Profile Metrics Aggregation

    static func aggregatedDonationTotal() -> Double {
        sharedDefaults?.double(forKey: Keys.profileTotalDonation) ?? 0
    }

    static func topCharities(limit: Int = 3) -> [CharityAggregate] {
        let map = loadCharityAggregates()
        let sorted = map.values.sorted { $0.amount > $1.amount }
        guard limit > 0 else { return sorted }
        return Array(sorted.prefix(limit))
    }

    static func unlockHistory() -> [UnlockStatsRecord] {
        let stats = loadUnlockStatsDictionary()
        return stats.values.sorted { $0.id > $1.id }
    }

    static func unlockStats(for date: Date) -> UnlockStatsRecord? {
        loadUnlockStatsDictionary()[dayString(for: date)]
    }

    static func estimatedUsageMinutes(for date: Date) -> Double {
        var baseMinutes: Double = 0
        if let usage = loadTodayUsage(),
           Calendar.current.isDate(usage.date, inSameDayAs: date) {
            let totalSeconds = usage.appSeconds.values.reduce(0, +)
            baseMinutes = totalSeconds / 60
        }
        let additional = unlockStats(for: date)?.totalMinutes ?? 0
        return baseMinutes + additional
    }

    static func recordUnlock(kind: UnlockEventKind) {
        var stats = loadUnlockStatsDictionary()
        let key = dayString(for: Date())
        var record = stats[key] ?? UnlockStatsRecord(id: key, freeUnlocks: 0, dayPassUnlocks: 0, freeMinutes: 0, dayPassMinutes: 0)

        switch kind {
        case .free(let minutes):
            guard minutes > 0 else { break }
            record.freeUnlocks += 1
            record.freeMinutes += minutes
        case .dayPass(let minutes):
            guard minutes > 0 else { break }
            record.dayPassUnlocks += 1
            record.dayPassMinutes += minutes
        }

        stats[key] = record
        pruneUnlockStats(&stats)
        saveUnlockStatsDictionary(stats)
    }

    // MARK: - Analytics Summaries (DeviceActivityReport)
    static func writeAnalyticsDaySummary(_ summary: AnalyticsDaySummary) {
        guard
            let summariesFolder = ensureAnalyticsSummaryDirectory(),
            let data = try? JSONEncoder().encode(summary)
        else { return }

        do {
            let fileURL = analyticsSummaryURL(for: summary.date, base: summariesFolder)
            print("📁 Writing analytics summary to: \(fileURL.path)")
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none.rawValue],
                ofItemAtPath: fileURL.path
            )
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: Keys.analyticsLastWrite)
        } catch {
            print("❌ Failed to persist analytics summary for \(summary.date): \(error)")
        }
    }

    static func updateAnalyticsDaySummary(for date: Date, mutate: (inout AnalyticsDaySummary) -> Void) {
        let day = dayString(for: date)
        var summary = readAnalyticsDaySummary(for: date) ?? AnalyticsDaySummary(
            date: day,
            totalScreenTime: 0,
            productiveSeconds: 0,
            distractingSeconds: 0,
            hourly: (0..<24).map { AnalyticsDaySummary.HourlyBucket(hour: $0, productive: 0, distracting: 0) },
            perApp: [],
            totalDonated: 0,
            blockCount: 0,
            charityBreakdown: []
        )
        mutate(&summary)
        writeAnalyticsDaySummary(summary)
    }

    static func recordBlockEvent(count: Int, on date: Date = Date()) {
        guard count > 0 else { return }
        updateAnalyticsDaySummary(for: date) { summary in
            let current = summary.blockCount ?? 0
            summary.blockCount = current + count
        }
    }

    static func recordDonation(amount: Double, charityId: String, charityName: String, on date: Date = Date()) {
        guard amount > 0 else { return }
        updateDonationAggregates(amount: amount, charityId: charityId, charityName: charityName)
        updateAnalyticsDaySummary(for: date) { summary in
            let currentTotal = summary.totalDonated ?? 0
            summary.totalDonated = currentTotal + amount

            var breakdown = summary.charityBreakdown ?? []
            if let index = breakdown.firstIndex(where: { $0.charityId == charityId }) {
                let existing = breakdown[index]
                breakdown[index] = AnalyticsDaySummary.CharityContribution(
                    charityId: charityId,
                    displayName: existing.displayName ?? charityName,
                    amount: existing.amount + amount
                )
            } else {
                breakdown.append(
                    AnalyticsDaySummary.CharityContribution(
                        charityId: charityId,
                        displayName: charityName,
                        amount: amount
                    )
                )
            }
            summary.charityBreakdown = breakdown
        }
    }

    static func readAnalyticsDaySummary(for date: Date) -> AnalyticsDaySummary? {
        guard let summariesFolder = ensureAnalyticsSummaryDirectory() else { return nil }
        let url = analyticsSummaryURL(for: date, base: summariesFolder)
        print("📂 Reading analytics summary at: \(url.path)")
        let exists = FileManager.default.fileExists(atPath: url.path)
        print("📂 File exists? \(exists)")
        if !exists {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: summariesFolder, includingPropertiesForKeys: nil)
                print("📂 Available summaries: \(contents.map { $0.lastPathComponent })")
            } catch {
                print("⚠️ Failed to enumerate AnalyticsSummaries folder: \(error)")
            }
        }
        if let data = try? Data(contentsOf: url) {
            print("📂 Loaded summary data (\(data.count) bytes)")
            if let summary = try? JSONDecoder().decode(AnalyticsDaySummary.self, from: data) {
                return summary
            } else {
                print("❌ Failed to decode AnalyticsDaySummary; raw JSON:\n\(String(data: data, encoding: .utf8) ?? "<non-UTF8>")")
            }
        }

        // Legacy fallback: read from UserDefaults if an older build stored it there.
        let day = dayString(for: date)
        if let legacyData = sharedDefaults?.data(forKey: Keys.analyticsDayKey(day)),
           let summary = try? JSONDecoder().decode(AnalyticsDaySummary.self, from: legacyData) {
            return summary
        }

        return nil
    }

    static func dayString(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    @discardableResult
    private static func ensureAnalyticsSummaryDirectory() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ App group container unavailable")
            return nil
        }

        let folder = container.appendingPathComponent("AnalyticsSummaries", isDirectory: true)
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        do {
            if fm.fileExists(atPath: folder.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    print("⚠️ Found file at AnalyticsSummaries path, removing before recreating directory")
                    try fm.removeItem(at: folder)
                    try fm.createDirectory(
                        at: folder,
                        withIntermediateDirectories: true,
                        attributes: [.protectionKey: FileProtectionType.none.rawValue]
                    )
                } else {
                    try fm.setAttributes(
                        [.protectionKey: FileProtectionType.none.rawValue],
                        ofItemAtPath: folder.path
                    )
                }
            } else {
                try fm.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.none.rawValue]
                )
            }
        } catch {
            print("❌ Failed to ensure AnalyticsSummaries directory: \(error)")
            return nil
        }

        return folder
    }

    private static func analyticsSummaryURL(for date: Date, base: URL) -> URL {
        analyticsSummaryURL(for: dayString(for: date), base: base)
    }

    private static func analyticsSummaryURL(for day: String, base: URL) -> URL {
        base.appendingPathComponent("\(day).json", isDirectory: false)
    }

    private static func updateDonationAggregates(amount: Double, charityId: String, charityName: String) {
        guard amount > 0 else { return }
        if let defaults = sharedDefaults {
            let total = (defaults.double(forKey: Keys.profileTotalDonation) + amount)
            defaults.set(total, forKey: Keys.profileTotalDonation)
        }

        var totals = loadCharityAggregates()
        var entry = totals[charityId] ?? CharityAggregate(id: charityId, name: charityName, amount: 0)
        entry.name = charityName
        entry.amount += amount
        totals[charityId] = entry
        saveCharityAggregates(totals)
    }

    private static func loadCharityAggregates() -> [String: CharityAggregate] {
        guard
            let data = sharedDefaults?.data(forKey: Keys.profileCharityTotals),
            let totals = try? JSONDecoder().decode([String: CharityAggregate].self, from: data)
        else {
            return [:]
        }
        return totals
    }

    private static func saveCharityAggregates(_ totals: [String: CharityAggregate]) {
        guard let data = try? JSONEncoder().encode(totals) else { return }
        sharedDefaults?.set(data, forKey: Keys.profileCharityTotals)
    }

    private static func loadUnlockStatsDictionary() -> [String: UnlockStatsRecord] {
        guard
            let data = sharedDefaults?.data(forKey: Keys.profileUnlockStats),
            let stats = try? JSONDecoder().decode([String: UnlockStatsRecord].self, from: data)
        else {
            return [:]
        }
        return stats
    }

    private static func saveUnlockStatsDictionary(_ stats: [String: UnlockStatsRecord]) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        sharedDefaults?.set(data, forKey: Keys.profileUnlockStats)
    }

    private static func pruneUnlockStats(_ stats: inout [String: UnlockStatsRecord]) {
        let sortedKeys = stats.keys.sorted(by: >)
        if sortedKeys.count <= 14 { return }
        for key in sortedKeys.dropFirst(14) {
            stats.removeValue(forKey: key)
        }
    }

    
    /// Persist the current selection of applications so the extension can access them.
    static func persistSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            sharedDefaults?.set(data, forKey: Keys.selectionData)
        }
    }
    
    /// Retrieve the stored application tokens used for blocking.
    static func storedApplicationTokens() -> Set<ApplicationToken> {
        guard let data = sharedDefaults?.data(forKey: Keys.selectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return []
        }
        return selection.applicationTokens
    }
    
    /// Store the most recent limit event so the host app can present the unlock flow.
    static func storeLimitEvent(name: String, blockedTokens: [ApplicationToken]) {
        sharedDefaults?.set(name, forKey: Keys.lastEventName)
        if let data = try? JSONEncoder().encode(blockedTokens) {
            sharedDefaults?.set(data, forKey: Keys.lastBlockedTokens)
        }
        sharedDefaults?.set(true, forKey: Keys.isBlocking)
        postLimitEventNotification()
        recordBlockEvent(count: blockedTokens.count, on: Date())
    }
    
    /// Fetch the most recent limit event, leaving it in storage until cleared manually.
    static func pendingLimitEvent() -> LimitEvent? {
        guard let defaults = sharedDefaults,
              let name = defaults.string(forKey: Keys.lastEventName) else {
            return nil
        }
        let tokens: [ApplicationToken]
        if let data = defaults.data(forKey: Keys.lastBlockedTokens),
           let decoded = try? JSONDecoder().decode([ApplicationToken].self, from: data) {
            tokens = decoded
        } else {
            tokens = []
        }
        return LimitEvent(eventName: name, blockedTokens: tokens)
    }
    
    /// Clear the stored limit event data.
    static func clearLimitEvent() {
        sharedDefaults?.removeObject(forKey: Keys.lastEventName)
        sharedDefaults?.removeObject(forKey: Keys.lastBlockedTokens)
    }
    
    /// Reflect the blocking state so both the app and the extension stay in sync.
    static func setBlockingState(_ isBlocking: Bool) {
        sharedDefaults?.set(isBlocking, forKey: Keys.isBlocking)
    }
    
    static func sharedBlockingState() -> Bool {
        sharedDefaults?.bool(forKey: Keys.isBlocking) ?? false
    }
    
    static func observeLimitEvents(_ handler: @escaping () -> Void) {
        LimitEventObserver.shared.setHandler(handler)
    }
    
    static func postLimitEventNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(limitEventNotificationName as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    static func extensionBundleIdentifier(fallback: String) -> String {
        if let id = Bundle.main.object(forInfoDictionaryKey: extensionBundleIdentifierKey) as? String,
           !id.isEmpty {
            return id
        }
        return fallback
    }
}

struct LimitEvent {
    let eventName: String
    let blockedTokens: [ApplicationToken]
}

extension ApplicationToken: Codable {
    var identifier: String {
        guard let data = try? JSONEncoder().encode(self) else {
            return ""
        }
        return data.base64EncodedString()
    }

    init?(identifier: String) {
        guard let data = Data(base64Encoded: identifier),
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else {
            return nil
        }
        self = token
    }
}

extension ApplicationToken: Identifiable, Equatable {
    public var id: String { identifier }
    
    public static func == (lhs: ApplicationToken, rhs: ApplicationToken) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

private final class LimitEventObserver {
    static let shared = LimitEventObserver()
    private var handler: (() -> Void)?
    
    private init() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = SharedSettings.limitEventNotificationName as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            LimitEventObserver.shared.emit()
        }, name, nil, .deliverImmediately)
    }
    
    func setHandler(_ handler: @escaping () -> Void) {
        self.handler = handler
    }
    
    private func emit() {
        let currentHandler = handler
        DispatchQueue.main.async {
            currentHandler?()
        }
    }
}
    // MARK: - Token Key Canonicalization
    /// Returns the canonical string key used to store ApplicationToken-based state
    /// in shared defaults. Centralizing this ensures both the host app and
    /// extensions use identical keys for lookups.
    static func tokenKey(_ token: ApplicationToken) -> String {
        // Currently we use the base64-encoded JSON identifier. Centralizing the
        // accessor lets us swap implementations later without touching call sites.
        return token.identifier
    }

    static func tokenKeys(_ tokens: [ApplicationToken]) -> [String] {
        tokens.map { tokenKey($0) }
    }
