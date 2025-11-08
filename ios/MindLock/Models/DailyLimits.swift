import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Daily Limits Data Model
struct DailyLimits: Codable, Equatable {
    let date: Date
    var appLimits: [String: TimeInterval] // App token identifier to seconds mapping
    let isActive: Bool
    
    init(date: Date, appLimits: [String: TimeInterval] = [:], isActive: Bool = false) {
        self.date = date
        self.appLimits = appLimits
        self.isActive = isActive
    }
    
    func limitForApp(_ token: ApplicationToken) -> TimeInterval? {
        return appLimits[token.identifier]
    }
    
    mutating func setLimit(for token: ApplicationToken, limit: TimeInterval) {
        appLimits = appLimits.merging([token.identifier: limit]) { _, new in new }
    }
}

// MARK: - App Usage Tracking
struct AppUsageDay: Codable, Equatable {
    let date: Date
    var appUsage: [String: TimeInterval] // App token identifier to seconds used
    
    init(date: Date) {
        self.date = date
        self.appUsage = [:]
    }
    
    func usageForApp(_ token: ApplicationToken) -> TimeInterval {
        return appUsage[token.identifier] ?? 0
    }
    
    mutating func addUsage(for token: ApplicationToken, duration: TimeInterval) {
        let currentUsage = usageForApp(token)
        appUsage[token.identifier] = currentUsage + duration
    }
    
    func remainingTimeForApp(_ token: ApplicationToken, limit: TimeInterval) -> TimeInterval {
        let used = usageForApp(token)
        return max(0, limit - used)
    }
    
    func hasExceededLimit(for token: ApplicationToken, limit: TimeInterval) -> Bool {
        return usageForApp(token) >= limit
    }
}
