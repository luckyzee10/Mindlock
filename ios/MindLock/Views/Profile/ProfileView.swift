import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    heroCard
                    unlockCard
                    usageGrid
                    topCharitiesSection
                    usageNotesSection
                }
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
        }
        .onAppear { viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.analyticsUpdatedNotification)) { _ in
            viewModel.refresh()
        }
    }
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Giving Impact")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(formatCurrency(viewModel.totalDonation))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Text(viewModel.totalDonation == 0 ? "Support your first cause to see impact here."
                         : "Across \(max(viewModel.topCharities.count, 1)) charities you love.")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
            }
            Divider()
                .background(Color.white.opacity(0.3))
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Charity")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(viewModel.topCharities.first?.name ?? "TBD")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.white)
                }
                Spacer()
                if viewModel.totalDonation > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg / Unlock")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(formatCurrency(viewModel.averageDonationPerUnlock))
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .shadow(color: DesignSystem.Colors.primary.opacity(0.35), radius: 20, x: 0, y: 10)
    }
    
    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlocks Today")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(viewModel.totalUnlocks)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        deltaChip
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mix")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(viewModel.unlockMixText)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            
            ProgressView(value: viewModel.unlockMixProgress)
                .progressViewStyle(
                    LinearProgressViewStyle(tint: DesignSystem.Colors.accent)
                )
                .frame(height: 6)
                .clipShape(Capsule())
            
            HStack {
                mixLegend(color: DesignSystem.Colors.accent, label: "Free", value: "\(viewModel.freeUnlocks)")
                Spacer()
                mixLegend(color: DesignSystem.Colors.primary, label: "Day Pass", value: "\(viewModel.dayPassUnlocks)")
            }
        }
        .padding()
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }
    
    private var usageGrid: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                usageCard(
                    title: "Estimated Usage",
                    value: formatMinutes(viewModel.estimatedUsageMinutes),
                    subtitle: "Tracked apps today",
                    icon: "clock.badge.checkmark",
                    tint: DesignSystem.Colors.success.opacity(0.8)
                )
                usageCard(
                    title: "Free Unlock Minutes",
                    value: formatMinutes(viewModel.freeUnlockMinutes),
                    subtitle: "Mindful breaks",
                    icon: "hourglass.bottomhalf.filled",
                    tint: DesignSystem.Colors.accent.opacity(0.9)
                )
            }
            usageCard(
                title: "Day Pass Minutes",
                value: formatMinutes(viewModel.dayPassMinutes),
                subtitle: "Full access windows",
                icon: "infinity.circle.fill",
                tint: DesignSystem.Colors.primary.opacity(0.85),
                fullWidth: true
            )
        }
    }
    
    private func usageCard(title: String, value: String, subtitle: String, icon: String, tint: Color, fullWidth: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(subtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private var topCharitiesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Top Charities")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if viewModel.topCharities.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Make your first Day Pass purchase to unlock detailed impact stats.")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.CornerRadius.md)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.topCharities) { charity in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(charity.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(formatCurrency(charity.amount))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            Capsule()
                                .fill(LinearGradient(colors: [DesignSystem.Colors.accent, DesignSystem.Colors.primary], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 6)
                        }
                        .padding()
                        .background(DesignSystem.Colors.surface)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
            }
        }
    }
    
    private var usageNotesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Text("How we estimate usage")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            Text("MindLock adds up time spent on tracked apps that hit their limit plus any unlock windows you triggered. Day Passes assume you made full use of the unlocked period, so actual usage may be lower.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surface.opacity(0.25))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var unlockDeltaText: String {
        guard let delta = viewModel.unlockDelta else {
            return viewModel.totalUnlocks == 0 ? "No unlocks yesterday" : "First unlock day"
        }
        let percent = abs(delta * 100).rounded()
        if percent == 0 {
            return "No change vs yesterday"
        }
        let arrow = delta > 0 ? "↑" : "↓"
        let formatted = String(format: "%.0f%%", percent)
        return "\(arrow) \(formatted) vs yesterday"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        NumberFormatter.currency.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        guard minutes > 0 else { return "0m" }
        if minutes >= 60 {
            let hours = minutes / 60
            if hours >= 1 {
                return String(format: "%.1fh", hours)
            }
        }
        return String(format: "%.0fm", minutes)
    }
    
    private func mixLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text("\(label) • \(value)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    private var deltaChip: some View {
        Group {
            if let delta = viewModel.unlockDelta {
                let arrow = delta > 0 ? "▲" : "▼"
                let percent = abs(delta * 100)
                Text("\(arrow) \(String(format: "%.0f%%", percent))")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (delta > 0 ? DesignSystem.Colors.error : DesignSystem.Colors.success)
                            .opacity(0.15)
                    )
                    .foregroundColor(delta > 0 ? DesignSystem.Colors.error : DesignSystem.Colors.success)
                    .cornerRadius(999)
            } else {
                Text("—")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let tint: Color
    
    init(title: String, value: String, subtitle: String? = nil, icon: String, tint: Color) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
                Spacer()
            }
            Spacer()
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text(value)
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

private final class ProfileViewModel: ObservableObject {
    @Published var totalDonation: Double = 0
    @Published var topCharities: [SharedSettings.CharityAggregate] = []
    @Published var totalUnlocks: Int = 0
    @Published var freeUnlocks: Int = 0
    @Published var dayPassUnlocks: Int = 0
    @Published var unlockDelta: Double?
    @Published var estimatedUsageMinutes: Double = 0
    @Published var freeUnlockMinutes: Double = 0
    @Published var dayPassMinutes: Double = 0
    
    func refresh() {
        totalDonation = SharedSettings.aggregatedDonationTotal()
        topCharities = SharedSettings.topCharities(limit: 3)
        
        var history: [String: SharedSettings.UnlockStatsRecord] = [:]
        for record in SharedSettings.unlockHistory() {
            history[record.id] = record
        }
        let today = Date()
        let todayKey = SharedSettings.dayString(for: today)
        if let todayStats = history[todayKey] {
            totalUnlocks = todayStats.totalUnlocks
            freeUnlocks = todayStats.freeUnlocks
            dayPassUnlocks = todayStats.dayPassUnlocks
            freeUnlockMinutes = todayStats.freeMinutes
            dayPassMinutes = todayStats.dayPassMinutes
        } else {
            totalUnlocks = 0
            freeUnlocks = 0
            dayPassUnlocks = 0
            freeUnlockMinutes = 0
            dayPassMinutes = 0
        }
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayKey = SharedSettings.dayString(for: yesterday)
        if let yesterdayStats = history[yesterdayKey], yesterdayStats.totalUnlocks > 0 {
            let deltaValue = Double(totalUnlocks - yesterdayStats.totalUnlocks) / Double(yesterdayStats.totalUnlocks)
            unlockDelta = deltaValue
        } else {
            unlockDelta = nil
        }
        
        estimatedUsageMinutes = SharedSettings.estimatedUsageMinutes(for: today)
    }
    
    var averageDonationPerUnlock: Double {
        guard totalUnlocks > 0, totalDonation > 0 else { return 0 }
        return totalDonation / Double(totalUnlocks)
    }
    
    var unlockMixText: String {
        if totalUnlocks == 0 { return "0 free · 0 day" }
        return "\(freeUnlocks) free · \(dayPassUnlocks) day"
    }
    
    var unlockMixProgress: Double {
        guard totalUnlocks > 0 else { return 0.5 }
        return Double(freeUnlocks) / Double(totalUnlocks)
    }
}

private extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter
    }()
    
}

#Preview {
    ProfileView()
}
