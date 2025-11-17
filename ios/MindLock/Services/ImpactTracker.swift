import Foundation

final class ImpactTracker {
    static let shared = ImpactTracker()
    private let cacheKey = "impactTracker.lastReport"
    private let defaults = UserDefaults.standard

    private init() {}

    func refreshImpactReport(reason: String = "manual") {
        Task.detached(priority: .utility) { [weak self] in
            await self?.submitReportIfNeeded(reason: reason)
        }
    }

    private func submitReportIfNeeded(reason: String) async {
        guard SharedSettings.isSubscriptionActive() else { return }
        guard let tier = SharedSettings.currentSubscriptionTier() else { return }
        let userIdentity = UserIdentity.shared
        let month = SharedSettings.monthIdentifier()
        let impactPoints = SharedSettings.monthlyImpactPoints()
        let streak = SharedSettings.consecutiveUnlockFreeDays()
        let multiplier = SharedSettings.impactMultiplier(forStreak: streak)

        if shouldSkipReport(month: month, points: impactPoints, tier: tier) {
            return
        }

        let request = ImpactReportRequest(
            userId: userIdentity.userId,
            userEmail: userIdentity.email,
            subscriptionTier: tier,
            month: month,
            impactPoints: impactPoints,
            streakDays: streak,
            multiplier: multiplier
        )

        do {
            try await APIClient.shared.submitImpactReport(request)
            storeLastReport(month: month, points: impactPoints, tier: tier)
        } catch {
            print("❌ Impact report failed (\(reason)): \(error)")
        }
    }

    private func shouldSkipReport(month: String, points: Int, tier: String) -> Bool {
        guard let cached = defaults.dictionary(forKey: cacheKey) else { return false }
        let cachedMonth = cached["month"] as? String
        let cachedPoints = cached["points"] as? Int
        let cachedTier = cached["tier"] as? String
        return cachedMonth == month && cachedPoints == points && cachedTier == tier
    }

    private func storeLastReport(month: String, points: Int, tier: String) {
        defaults.set(["month": month, "points": points, "tier": tier], forKey: cacheKey)
    }
}
