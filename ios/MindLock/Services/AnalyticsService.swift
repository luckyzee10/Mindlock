import Foundation
import os

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "Analytics")
    private let defaults = UserDefaults.standard
    private let sessionId = UUID().uuidString

    private init() {}

    func track(_ event: AnalyticsEvent, properties: [String: AnalyticsValue] = [:]) {
        var payload = properties
        payload["session_id"] = .string(sessionId)
        payload["timestamp"] = .string(ISO8601DateFormatter().string(from: Date()))
        payload["app_version"] = .string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        payload["build_number"] = .string(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")

        appendLocalEvent(name: event.rawValue, properties: payload)
        logger.info("event=\(event.rawValue, privacy: .public) properties=\(payload.debugDescription, privacy: .public)")
    }

    func identifyCurrentUser() {
        track(.userIdentified, properties: [
            "user_id": .string(UserIdentity.shared.userId),
            "subscription_active": .bool(SharedSettings.isSubscriptionActive()),
            "preferred_language": .string(SharedSettings.preferredLearningLanguage().rawValue),
            "unlock_method": .string(SharedSettings.preferredUnlockMechanism().rawValue)
        ])
    }

    private func appendLocalEvent(name: String, properties: [String: AnalyticsValue]) {
        let event = StoredAnalyticsEvent(name: name, properties: properties.mapValues(\.storedValue))
        var events = loadLocalEvents()
        events.append(event)
        if events.count > 200 {
            events = Array(events.suffix(200))
        }
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: "analytics.local.events")
        }
    }

    private func loadLocalEvents() -> [StoredAnalyticsEvent] {
        guard let data = defaults.data(forKey: "analytics.local.events"),
              let events = try? JSONDecoder().decode([StoredAnalyticsEvent].self, from: data) else {
            return []
        }
        return events
    }
}

enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case appForegrounded = "app_foregrounded"
    case userIdentified = "user_identified"

    case onboardingStarted = "onboarding_started"
    case onboardingPageViewed = "onboarding_page_viewed"
    case onboardingUsageSelected = "onboarding_usage_selected"
    case onboardingAgeSelected = "onboarding_age_selected"
    case onboardingGoalSelected = "onboarding_goal_selected"
    case onboardingLanguageSelected = "onboarding_language_selected"
    case onboardingUnlockMethodSelected = "onboarding_unlock_method_selected"
    case onboardingCompleted = "onboarding_completed"

    case screenTimePermissionRequested = "screen_time_permission_requested"
    case screenTimePermissionGranted = "screen_time_permission_granted"
    case screenTimePermissionFailed = "screen_time_permission_failed"

    case appsSelected = "apps_selected"
    case limitCreated = "limit_created"
    case timeBlockCreated = "time_block_created"

    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchasePending = "purchase_pending"
    case purchaseCancelled = "purchase_cancelled"
    case restoreTapped = "restore_tapped"
    case restoreCompleted = "restore_completed"
    case restoreFailed = "restore_failed"

    case unlockFlowStarted = "unlock_flow_started"
    case unlockMinutesGranted = "unlock_minutes_granted"
    case languageChallengeStarted = "language_challenge_started"
    case languageChallengeCompleted = "language_challenge_completed"
}

enum AnalyticsValue: CustomDebugStringConvertible {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var storedValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .bool(let value): return value ? "true" : "false"
        }
    }

    var debugDescription: String {
        storedValue
    }
}

private struct StoredAnalyticsEvent: Codable {
    let name: String
    let properties: [String: String]
}
