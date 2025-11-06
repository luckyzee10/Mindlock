import SwiftUI
import DeviceActivity
import _DeviceActivity_SwiftUI
import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import OSLog

@main
struct UsageReportExtension: DeviceActivityReportExtension {
    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "UsageReportExtension")

    init() {
        logger.info("🧾 UsageReportExtension initialized")
        print("🧾 UsageReportExtension initialized (print)")
    }
    
    var body: some DeviceActivityReportScene {
        MindLockUsageReportScene()
    }
}

struct MindLockUsageReportScene: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("MindLockUsage")
    private let logger = Logger(subsystem: "com.lucaszambranonavia.mindlock", category: "UsageReportScene")

    typealias Configuration = AnalyticsDaySummary?
    typealias Content = MindLockUsageReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Configuration {
        logger.info("🧾 makeConfiguration invoked for report context")
        print("🧾 makeConfiguration invoked (print)")
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedSettings.appGroupIdentifier) {
            print("📁 Extension app-group path: \(containerURL.path)")
        } else {
            print("❌ Extension failed to resolve app-group container")
        }
        let summary = await UsageSummaryProcessor().process(results: data)
        return summary
    }

    let content: (Configuration) -> MindLockUsageReportView = { summary in
        MindLockUsageReportView(summary: summary)
    }
}

struct MindLockUsageReportView: View {
    let summary: AnalyticsDaySummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let summary {
                    TotalsCard(summary: summary)
                    QuickStatsCard(summary: summary)
                    TopAppsSection(apps: Array(summary.perApp.prefix(5)))
                    HourlyBreakdownSection(hourly: summary.hourly)
                } else {
                    loadingState
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analytics")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.primary)
            Text("Daily usage summary for your focused mind")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Generating latest usage insights…")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}

// MARK: - Subviews

private struct TotalsCard: View {
    let summary: AnalyticsDaySummary

    private var totalString: String {
        MindLockUsageReportView.formatTime(summary.totalScreenTime)
    }

    private var focusedPercent: Int {
        guard summary.totalScreenTime > 0 else { return 0 }
        return Int((summary.productiveSeconds / summary.totalScreenTime) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(totalString)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(Color.primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(MindLockUsageReportView.formatTime(summary.productiveSeconds), systemImage: "sparkles")
                        .foregroundColor(Color.green)
                    Spacer()
                    Text("Focused")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label(MindLockUsageReportView.formatTime(summary.distractingSeconds), systemImage: "exclamationmark.triangle")
                        .foregroundColor(Color.orange)
                    Spacer()
                    Text("Distracting")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if summary.totalScreenTime > 0 {
                    ProgressView(value: Double(focusedPercent), total: 100)
                        .tint(Color.green)
                    Text("Focused time \(focusedPercent)% of the day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

private struct QuickStatsCard: View {
    let summary: AnalyticsDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick stats")
                .font(.headline)

            HStack(spacing: 12) {
                StatTile(title: "Apps tracked", value: "\(summary.perApp.count)")
                StatTile(title: "Blocks today", value: "\(summary.blockCount ?? 0)")
                StatTile(title: "Donated", value: MindLockUsageReportView.formatCurrency(summary.totalDonated ?? 0))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(12)
    }
}

private struct TopAppsSection: View {
    let apps: [AnalyticsDaySummary.PerAppUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top apps")
                .font(.headline)
            if apps.isEmpty {
                Text("No tracked apps yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(apps, id: \.tokenId) { app in
                    HStack(spacing: 12) {
                        AppAvatar(app: app)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MindLockUsageReportView.displayName(for: app))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            ClassificationLabel(isDistracting: app.isDistracting ?? false)
                        }
                        Spacer()
                        Text(MindLockUsageReportView.formatTime(app.seconds))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    if app.tokenId != apps.last?.tokenId {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}

private struct AppAvatar: View {
    let app: AnalyticsDaySummary.PerAppUsage

    var body: some View {
        if let token = decodedToken {
            Label(token)
                .labelStyle(LargeAppIconLabelStyle())
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accentColor.opacity(0.95), accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }

    private var decodedToken: ApplicationToken? {
        guard app.hasToken == true else { return nil }
        return ApplicationToken(identifier: app.tokenId)
    }

    private var initials: String {
        let name = MindLockUsageReportView.displayName(for: app)
        return String(name.prefix(1)).uppercased()
    }
    private var accentColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal]
        let hash = abs(app.tokenId.hashValue)
        return colors[hash % colors.count]
    }
}

private struct ClassificationLabel: View {
    let isDistracting: Bool

    var body: some View {
        Text(isDistracting ? "Distracting" : "Productive")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isDistracting ? Color.red.opacity(0.15) : Color.green.opacity(0.15)))
            .foregroundColor(isDistracting ? Color.red : Color.green)
            .clipShape(Capsule())
    }
}

private struct LargeAppIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.icon
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
    }
}

private struct HourlyBreakdownSection: View {
    let hourly: [AnalyticsDaySummary.HourlyBucket]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly breakdown")
                .font(.headline)

            let activeBuckets = hourly.filter { $0.productive + $0.distracting > 0 }
            let maxValue = activeBuckets.map { $0.productive + $0.distracting }.max() ?? 0

            if activeBuckets.isEmpty {
                Text("No activity recorded today.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(activeBuckets, id: \.hour) { bucket in
                    let total = bucket.productive + bucket.distracting

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(String(format: "%02d:00", bucket.hour))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(MindLockUsageReportView.formatTime(total))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        GeometryReader { proxy in
                            let width = maxValue > 0 ? proxy.size.width * total / maxValue : 0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(uiColor: .tertiarySystemFill))
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(width: width)
                            }
                            .frame(height: 8)
                        }
                        .frame(height: 8)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Helpers

extension MindLockUsageReportView {
    private static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func formatTime(_ seconds: TimeInterval) -> String {
        if seconds == 0 { return "0m" }
        return timeFormatter.string(from: seconds) ?? "0m"
    }

    static func formatCurrency(_ amount: Double) -> String {
        guard amount > 0 else { return "–" }
        return currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    static func displayName(for app: AnalyticsDaySummary.PerAppUsage) -> String {
        if let token = appToken(app), let resolved = Application(token: token).localizedDisplayName, !resolved.isEmpty {
            return resolved
        }
        if let name = app.displayName, !name.isEmpty { return name }
        if let bundle = app.bundleIdentifier, !bundle.isEmpty { return bundle }
        if app.hasToken == true { return "Tracked App" }
        return "App"
    }

    private static func appToken(_ app: AnalyticsDaySummary.PerAppUsage) -> ApplicationToken? {
        guard app.hasToken == true else { return nil }
        return ApplicationToken(identifier: app.tokenId)
    }
}
