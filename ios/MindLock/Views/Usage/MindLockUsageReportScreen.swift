import SwiftUI
import FamilyControls
import ManagedSettings

struct MindLockUsageReportScreen: View {
    @State private var summary: AnalyticsDaySummary? = SharedSettings.readAnalyticsDaySummary(for: Date())
    private let analyticsNotification = SharedSettings.analyticsUpdatedNotification

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
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .onAppear(perform: reloadSummary)
        .onReceive(NotificationCenter.default.publisher(for: analyticsNotification)) { _ in
            reloadSummary()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Report")
                .font(DesignSystem.Typography.title1)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Daily Screen Time insights from your latest MindLock summary.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Waiting for latest usage insights…")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(DesignSystem.Colors.surfaceSecondary)
        .cornerRadius(20)
    }

    private func reloadSummary() {
        summary = SharedSettings.readAnalyticsDaySummary(for: Date())
    }
}

// MARK: - Subviews

private struct TotalsCard: View {
    let summary: AnalyticsDaySummary

    private var totalString: String {
        MindLockUsageReportScreen.formatTime(summary.totalScreenTime)
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
                .foregroundColor(DesignSystem.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(MindLockUsageReportScreen.formatTime(summary.productiveSeconds), systemImage: "sparkles")
                        .foregroundColor(.green)
                    Spacer()
                    Text("Focused")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label(MindLockUsageReportScreen.formatTime(summary.distractingSeconds), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("Distracting")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if summary.totalScreenTime > 0 {
                    ProgressView(value: Double(focusedPercent), total: 100)
                        .tint(.green)
                    Text("Focused time \(focusedPercent)% of the day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.surfaceSecondary)
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
                StatTile(title: "Donated", value: MindLockUsageReportScreen.formatCurrency(summary.totalDonated ?? 0))
            }
        }
        .padding()
        .background(DesignSystem.Colors.surfaceSecondary)
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
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.surface)
        .cornerRadius(12)
    }
}

private struct TopAppsSection: View {
    let apps: [AnalyticsDaySummary.PerAppUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top apps")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            if apps.isEmpty {
                Text("No tracked apps yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(apps, id: \.tokenId) { app in
                    HStack(spacing: 12) {
                        AppAvatar(app: app)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MindLockUsageReportScreen.displayName(for: app))
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            ClassificationLabel(isDistracting: app.isDistracting ?? false)
                        }
                        Spacer()
                        Text(MindLockUsageReportScreen.formatTime(app.seconds))
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
        .background(DesignSystem.Colors.surfaceSecondary)
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
        let name = MindLockUsageReportScreen.displayName(for: app)
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
            .foregroundColor(isDistracting ? .red : .green)
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
                .foregroundColor(DesignSystem.Colors.textPrimary)

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
                            Text(MindLockUsageReportScreen.formatTime(total))
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
        .background(DesignSystem.Colors.surfaceSecondary)
        .cornerRadius(16)
    }
}

// MARK: - Helpers

extension MindLockUsageReportScreen {
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
