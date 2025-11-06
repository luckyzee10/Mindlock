import Foundation
import DeviceActivity
import _DeviceActivity_SwiftUI
import FamilyControls
import ManagedSettings
import OSLog

/// Aggregates the latest DeviceActivity results into a compact daily summary that
/// the main app can consume from the shared app group.
struct UsageSummaryProcessor {
    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "UsageSummary")
    private let calendar = Calendar(identifier: .gregorian)

    private enum AppUsageClassification {
        case productive
        case distracting
    }

    @discardableResult
    func process(results: DeviceActivityResults<DeviceActivityData>) async -> AnalyticsDaySummary? {
        guard let summary = await aggregate(results: results) else {
            logger.debug("No activity segments available to summarize.")
            return nil
        }

        SharedSettings.writeAnalyticsDaySummary(summary)
        logger.debug("Wrote analytics summary for day: \(summary.date, privacy: .public)")
        return summary
    }

    private func aggregate(results: DeviceActivityResults<DeviceActivityData>) async -> AnalyticsDaySummary? {
        let blockedTokens = SharedSettings.storedApplicationTokens()

        struct AppAggregate {
            var seconds: TimeInterval
            var displayName: String?
            var bundleIdentifier: String?
            var hasToken: Bool
            var classification: AppUsageClassification
        }

        var perApp: [String: AppAggregate] = [:]
        var hourly: [Int: HourAccumulator] = [:]
        var totalProductive: TimeInterval = 0
        var totalDistracting: TimeInterval = 0
        var earliestDate: Date?

        var segmentCount = 0
        var applicationCount = 0
        for await data in results {
            print("📦 Received DeviceActivityData: segmentInterval=\(data.segmentInterval), lastUpdated=\(data.lastUpdatedDate)")
            for await segment in data.activitySegments {
                segmentCount += 1
                print("  ⏱️ Segment \(segmentCount): duration=\(segment.totalActivityDuration)")
                earliestDate = minDate(earliestDate, segment.dateInterval.start)

                var segmentProductive: TimeInterval = 0
                var segmentDistracting: TimeInterval = 0
                var attributed: TimeInterval = 0

                for await category in segment.categories {
                    for await applicationActivity in category.applications {
                        applicationCount += 1
                        let app = applicationActivity.application
                        let displayName = app.localizedDisplayName
                        let bundleID = app.bundleIdentifier
                        let token = app.token
                        let identifier: String
                        let hasToken: Bool
                        if let token {
                            identifier = token.identifier
                            hasToken = true
                        } else if let bundleID {
                            identifier = "bundle:\(bundleID)"
                            hasToken = false
                        } else if let name = displayName {
                            identifier = "name:\(name)"
                            hasToken = false
                        } else {
                            identifier = UUID().uuidString
                            hasToken = false
                        }

                        let duration = applicationActivity.totalActivityDuration
                        print("    📱 App activity id=\(identifier) duration=\(duration)")
                        let classification: AppUsageClassification
                        if let existing = perApp[identifier] {
                            classification = existing.classification
                        } else {
                            classification = classifyApp(name: displayName, bundleID: bundleID)
                        }

                        var aggregate = perApp[identifier] ?? AppAggregate(seconds: 0, displayName: displayName, bundleIdentifier: bundleID, hasToken: hasToken, classification: classification)
                        aggregate.seconds += duration
                        if aggregate.displayName == nil { aggregate.displayName = displayName }
                        if aggregate.bundleIdentifier == nil { aggregate.bundleIdentifier = bundleID }
                        aggregate.hasToken = aggregate.hasToken || hasToken
                        perApp[identifier] = aggregate

                        if let token, blockedTokens.contains(token) {
                            segmentDistracting += duration
                        } else {
                            segmentProductive += duration
                        }

                        attributed += duration
                    }
                }

                // Attribute any remaining time (for example, web domains or unmatched activity)
                // to the distracting bucket so totals remain consistent.
                let residual = max(0, segment.totalActivityDuration - attributed)
                if residual > 0 {
                    segmentDistracting += residual
                }

                totalProductive += segmentProductive
                totalDistracting += segmentDistracting

                let hour = calendar.component(.hour, from: segment.dateInterval.start)
                var bucket = hourly[hour, default: HourAccumulator()]
                bucket.productive += segmentProductive
                bucket.distracting += segmentDistracting
                hourly[hour] = bucket
            }
        }

        guard let baseDate = earliestDate.map({ calendar.startOfDay(for: $0) }) else {
            print("⚠️ No activity segments found for requested interval.")
            return nil
        }
        
        print("📊 Aggregation summary: segments=\(segmentCount) applications=\(applicationCount)")

        let existing = SharedSettings.readAnalyticsDaySummary(for: baseDate)
        let totalScreenTime = totalProductive + totalDistracting

        let hourlyBuckets = (0..<24).map { hour -> AnalyticsDaySummary.HourlyBucket in
            let bucket = hourly[hour] ?? HourAccumulator()
            return AnalyticsDaySummary.HourlyBucket(hour: hour, productive: bucket.productive, distracting: bucket.distracting)
        }

        let perAppEntries = perApp
            .map {
                AnalyticsDaySummary.PerAppUsage(
                    tokenId: $0.key,
                    seconds: $0.value.seconds,
                    displayName: $0.value.displayName,
                    bundleIdentifier: $0.value.bundleIdentifier,
                    hasToken: $0.value.hasToken,
                    isDistracting: $0.value.classification == .distracting
                )
            }
            .sorted { $0.seconds > $1.seconds }

        let summary = AnalyticsDaySummary(
            date: SharedSettings.dayString(for: baseDate),
            totalScreenTime: totalScreenTime,
            productiveSeconds: totalProductive,
            distractingSeconds: totalDistracting,
            hourly: hourlyBuckets,
            perApp: perAppEntries,
            totalDonated: existing?.totalDonated,
            blockCount: existing?.blockCount,
            charityBreakdown: existing?.charityBreakdown
        )

        let roundedTotal = Int(summary.totalScreenTime.rounded())
        let roundedProductive = Int(summary.productiveSeconds.rounded())
        let roundedDistracting = Int(summary.distractingSeconds.rounded())

        print("📊 Usage summary aggregated for \(summary.date): total=\(roundedTotal)s productive=\(roundedProductive)s distracting=\(roundedDistracting)s apps=\(perAppEntries.count)")
        logger.debug(
            "Aggregated \(summary.date, privacy: .public) — screenTime: \(roundedTotal, privacy: .public)s, productive: \(roundedProductive, privacy: .public)s, distracting: \(roundedDistracting, privacy: .public)s, apps: \(perAppEntries.count, privacy: .public)"
        )

        return summary
    }

    private func minDate(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else { return candidate }
        return min(current, candidate)
    }

    private func classifyApp(name: String?, bundleID: String?) -> AppUsageClassification {
        let lowercasedName = name?.lowercased() ?? ""
        let identifier = bundleID?.lowercased() ?? ""

        let distractingKeywords = [
            "instagram", "tiktok", "snap", "snapchat", "youtube", "netflix", "hulu",
            "game", "games", "playstation", "xbox", "twitch", "discord", "reddit",
            "facebook", "twitter", "threads", "pinterest", "music", "spotify",
            "primevideo", "com.netflix", "com.burbn.instagram", "com.cardify.tinder"
        ]

        let productiveKeywords = [
            "calendar", "mail", "notes", "notion", "slack", "teams", "zoom", "docs",
            "sheets", "drive", "trello", "asana", "todo", "reminder", "mindlock",
            "bank", "finance", "learn", "reading", "study", "calm", "health"
        ]

        for keyword in distractingKeywords {
            if lowercasedName.contains(keyword) || identifier.contains(keyword) {
                return .distracting
            }
        }

        for keyword in productiveKeywords {
            if lowercasedName.contains(keyword) || identifier.contains(keyword) {
                return .productive
            }
        }

        return .productive
    }
}

private struct HourAccumulator {
    var productive: TimeInterval = 0
    var distracting: TimeInterval = 0
}
