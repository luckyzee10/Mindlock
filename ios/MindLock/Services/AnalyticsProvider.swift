import Foundation
import FamilyControls
import ManagedSettings
import OSLog

/// Reads analytics summaries from the App Group, and produces snapshots for the UI.
final class AnalyticsProvider {
    private let mock = AnalyticsMockDataProvider()
    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "AnalyticsProvider")

    func snapshot(for timeframe: AnalyticsTimeframe) -> AnalyticsSnapshot {
        switch timeframe {
        case .today:
            if let summary = SharedSettings.readAnalyticsDaySummary(for: Date()) {
                logger.debug("Loaded real analytics for today (\(summary.date, privacy: .public))")
                return map(summary: summary)
            } else {
                logger.debug("No analytics summary for today. Falling back to mock data.")
                return mock.snapshot(for: .today)
            }
        case .week:
            // Minimal viable: aggregate last 7 day files if present; else mocks
            let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
            let summaries = days.compactMap { SharedSettings.readAnalyticsDaySummary(for: $0) }
            if summaries.isEmpty {
                logger.debug("No weekly analytics yet. Using mock snapshot.")
                return mock.snapshot(for: .week)
            }
            logger.debug("Aggregating \(summaries.count) daily summaries for weekly analytics.")
            return aggregate(summaries: summaries, timeframe: .week)
        case .month:
            let days = (0..<28).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
            let summaries = days.compactMap { SharedSettings.readAnalyticsDaySummary(for: $0) }
            if summaries.isEmpty {
                logger.debug("No monthly analytics yet. Using mock snapshot.")
                return mock.snapshot(for: .month)
            }
            logger.debug("Aggregating \(summaries.count) daily summaries for monthly analytics.")
            return aggregate(summaries: summaries, timeframe: .month)
        }
    }

    private func map(summary: AnalyticsDaySummary) -> AnalyticsSnapshot {
        let goalSeconds: TimeInterval = UserDefaults.standard.double(forKey: "dailyGoalSeconds").nonZeroOr(3*3600)
        let productive = summary.productiveSeconds
        let distracting = summary.distractingSeconds
        let total = summary.totalScreenTime
        let goalProgress = total == 0 ? 0 : min(1, total / goalSeconds)

        let hourly = summary.hourly.map { bucket -> UsagePoint in
            let totalUsage = bucket.productive + bucket.distracting
            let label = String(format: "%02d:00", bucket.hour)
            return UsagePoint(hourLabel: label, usage: totalUsage)
        }
        let perApp = appUsageList(from: summary.perApp)
        let totalDonated = summary.totalDonated ?? 0
        let blocks = summary.blockCount ?? 0
        let charityShares = makeCharityShares(
            from: (summary.charityBreakdown ?? []).map { contribution in
                (name: contribution.displayName ?? "Charity", amount: contribution.amount)
            },
            fallbackTotal: totalDonated
        )
        return AnalyticsSnapshot(
            timeframe: .today,
            totalScreenTime: total,
            timeOffScreen: max(0, 24*3600 - total),
            dailyGoal: goalSeconds,
            totalDonated: totalDonated,
            blocks: blocks,
            goalProgress: goalProgress,
            appUsage: perApp.sorted { $0.usage > $1.usage },
            hourlyBreakdown: hourly,
            productivityScore: (productive + distracting) == 0 ? 1 : productive / (productive + distracting),
            charityBreakdown: charityShares
        )
    }

    private func aggregate(summaries: [AnalyticsDaySummary], timeframe: AnalyticsTimeframe) -> AnalyticsSnapshot {
        let total = summaries.reduce(0) { $0 + $1.totalScreenTime }
        let productive = summaries.reduce(0) { $0 + $1.productiveSeconds }
        let distracting = summaries.reduce(0) { $0 + $1.distractingSeconds }
        let goalSeconds: TimeInterval = UserDefaults.standard.double(forKey: "dailyGoalSeconds").nonZeroOr(3*3600)
        let days = Double(max(1, summaries.count))
        let goalProgress = min(1, (total/days)/goalSeconds)
        // Simple rollup: top per-app by total seconds
        var perAppTotals: [String: (seconds: TimeInterval, displayName: String?, bundle: String?, hasToken: Bool)] = [:]
        for summary in summaries {
            for app in summary.perApp {
                var existing = perAppTotals[app.tokenId] ?? (0, app.displayName, app.bundleIdentifier, app.hasToken ?? false)
                existing.seconds += app.seconds
                if existing.displayName == nil { existing.displayName = app.displayName }
                if existing.bundle == nil { existing.bundle = app.bundleIdentifier }
                existing.hasToken = existing.hasToken || (app.hasToken ?? false)
                perAppTotals[app.tokenId] = existing
            }
        }
        let aggregatedPerApp = perAppTotals.map { id, entry in
            AnalyticsDaySummary.PerAppUsage(
                tokenId: id,
                seconds: entry.seconds,
                displayName: entry.displayName,
                bundleIdentifier: entry.bundle,
                hasToken: entry.hasToken
            )
        }
        let appUsage = appUsageList(from: aggregatedPerApp)
        let totalDonated = summaries.reduce(0) { $0 + ($1.totalDonated ?? 0) }
        let blocks = summaries.reduce(0) { $0 + ($1.blockCount ?? 0) }
        var aggregatedContributions: [String: (name: String, amount: Double)] = [:]
        for summary in summaries {
            for contribution in summary.charityBreakdown ?? [] {
                let existing = aggregatedContributions[contribution.charityId]
                let name = contribution.displayName ?? existing?.name ?? "Charity"
                aggregatedContributions[contribution.charityId] = (
                    name: name,
                    amount: (existing?.amount ?? 0) + contribution.amount
                )
            }
        }
        let charityShares = makeCharityShares(
            from: aggregatedContributions.values.map { ($0.name, $0.amount) },
            fallbackTotal: totalDonated
        )
        // Hourly aggregation omitted for brevity (kept as empty or last day)
        return AnalyticsSnapshot(
            timeframe: timeframe,
            totalScreenTime: total,
            timeOffScreen: max(0, days*24*3600 - total),
            dailyGoal: goalSeconds,
            totalDonated: totalDonated,
            blocks: blocks,
            goalProgress: goalProgress,
            appUsage: appUsage,
            hourlyBreakdown: [],
            productivityScore: (productive + distracting) == 0 ? 1 : productive / (productive + distracting),
            charityBreakdown: charityShares
        )
    }

    private func makeCharityShares(from contributions: [(name: String, amount: Double)], fallbackTotal: Double) -> [CharityShare] {
        let filtered = contributions.filter { $0.amount > 0 }
        let contributionsTotal = filtered.reduce(0) { $0 + $1.amount }
        let denominator = fallbackTotal > 0 ? fallbackTotal : contributionsTotal
        guard denominator > 0 else { return [] }
        return filtered
            .map { contribution in
                let percentage = max(0, contribution.amount / denominator)
                return CharityShare(charityName: contribution.name, amount: contribution.amount, percentage: percentage)
            }
            .sorted { $0.amount > $1.amount }
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double { self > 0 ? self : fallback }
}

private extension AnalyticsProvider {
    func appUsageList(from entries: [AnalyticsDaySummary.PerAppUsage]) -> [AppUsageData] {
        guard !entries.isEmpty else { return [] }
        var major: [AppUsageData] = []
        var otherTotal: TimeInterval = 0
        for entry in entries.sorted(by: { $0.seconds > $1.seconds }) {
            if entry.seconds < 60 {
                otherTotal += entry.seconds
                continue
            }
            major.append(makeAppUsageData(from: entry))
        }
        if otherTotal > 0 {
            major.append(
                AppUsageData(
                    appName: "Other",
                    usage: otherTotal,
                    category: .productivity,
                    iconName: "ellipsis.circle.fill",
                    trend: .flat
                )
            )
        }
        return major
    }

    func makeAppUsageData(from entry: AnalyticsDaySummary.PerAppUsage) -> AppUsageData {
        let hasToken = entry.hasToken ?? false
        var name: String?
        if hasToken, let token = ApplicationToken(identifier: entry.tokenId) {
            name = Application(token: token).localizedDisplayName
        }
        if name?.isEmpty ?? true {
            name = entry.displayName ?? entry.bundleIdentifier
        }
        let appName = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : "App"
        return AppUsageData(
            appName: appName,
            usage: entry.seconds,
            category: .productivity,
            iconName: "apps.iphone",
            trend: .flat
        )
    }
}
