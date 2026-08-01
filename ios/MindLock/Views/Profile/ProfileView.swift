import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    heroCard
                    StreakCard(days: viewModel.perfectDays)
                    skillProgressCard
                    learningStatsCard
                    unlockCard
                }
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.AppBackground())
            .navigationTitle("Profile")
        }
        .onAppear { viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.analyticsUpdatedNotification)) { _ in
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.learningLanguageChangedNotification)) { _ in
            viewModel.refresh()
        }
    }
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.learningLanguage.displayName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("Level \(viewModel.languageLevel)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(viewModel.weeklyXP) XP this week")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.white)
                    .shadow(radius: 12)
            }

            Divider().background(Color.white.opacity(0.25))

            HStack(spacing: DesignSystem.Spacing.xl) {
                profileMetric(title: "Perfect days", value: "\(viewModel.perfectDays)")
                profileMetric(title: "Level progress", value: "\(viewModel.currentLevelXP)/\(viewModel.nextLevelXP)")
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.success],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .shadow(color: DesignSystem.Colors.primary.opacity(0.35), radius: 20, x: 0, y: 10)
    }

    private func profileMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white.opacity(0.75))
            Text(value)
                .font(DesignSystem.Typography.title3.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    private var learningStatsCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            MetricCard(
                title: "Practiced",
                value: "\(viewModel.languageQuestionsThisWeek)",
                subtitle: "This week",
                icon: "text.book.closed.fill",
                tint: DesignSystem.Colors.primary
            )

            MetricCard(
                title: "Remembered",
                value: "\(viewModel.languageCorrectThisWeek)",
                subtitle: "Correct answers",
                icon: "checkmark.circle.fill",
                tint: DesignSystem.Colors.success
            )
        }
    }

    private var skillProgressCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Skill Progress")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ForEach(SharedSettings.LanguageSkill.allCases) { skill in
                skillProgressRow(skill)
            }
        }
        .padding()
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private func skillProgressRow(_ skill: SharedSettings.LanguageSkill) -> some View {
        let xp = viewModel.skillXP[skill] ?? 0
        let level = max(1, (xp / 80) + 1)
        let progress = CGFloat((xp % 80)) / 80.0

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(skill.displayName)
                    .font(DesignSystem.Typography.callout.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("Lv \(level)")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(skillTint(skill))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }

    private func skillTint(_ skill: SharedSettings.LanguageSkill) -> Color {
        switch skill {
        case .vocabulary: return DesignSystem.Colors.primary
        case .sentenceBuilding: return DesignSystem.Colors.accent
        case .grammar: return DesignSystem.Colors.warning
        case .recall: return DesignSystem.Colors.success
        }
    }
    
    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Language unlocks today")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(viewModel.mindfulUnlocks)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    deltaChip
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatMinutes(viewModel.mindfulUnlockMinutes))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Minutes granted")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding()
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl)
        .cornerRadius(DesignSystem.CornerRadius.xl)
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
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

private final class ProfileViewModel: ObservableObject {
    @Published var learningLanguage: SharedSettings.LearningLanguage = SharedSettings.preferredLearningLanguage()
    @Published var languageLevel: Int = 1
    @Published var weeklyXP: Int = 0
    @Published var currentLevelXP: Int = 0
    @Published var nextLevelXP: Int = 120
    @Published var skillXP: [SharedSettings.LanguageSkill: Int] = [:]
    @Published var languageQuestionsThisWeek: Int = 0
    @Published var languageCorrectThisWeek: Int = 0
    @Published var perfectDays: Int = 0
    @Published var mindfulUnlocks: Int = 0
    @Published var unlockDelta: Double?
    @Published var mindfulUnlockMinutes: Double = 0

    func refresh() {
        loadUnlockStats()
        loadLanguageStats()
    }

    private func loadLanguageStats() {
        let summary = SharedSettings.languageProgressSummary()
        learningLanguage = SharedSettings.preferredLearningLanguage()
        languageLevel = summary.level
        weeklyXP = summary.weeklyXP
        currentLevelXP = summary.currentLevelXP
        nextLevelXP = summary.nextLevelXP
        skillXP = summary.skillXP
        languageQuestionsThisWeek = summary.practicedThisWeek
        languageCorrectThisWeek = summary.correctThisWeek
    }

    private func loadUnlockStats() {
        var history: [String: SharedSettings.UnlockStatsRecord] = [:]
        for record in SharedSettings.unlockHistory() {
            history[record.id] = record
        }
        let today = Date()
        let todayKey = SharedSettings.dayString(for: today)
        if let todayStats = history[todayKey] {
            mindfulUnlocks = todayStats.totalUnlocks
            mindfulUnlockMinutes = todayStats.freeMinutes
        } else {
            mindfulUnlocks = 0
            mindfulUnlockMinutes = 0
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayKey = SharedSettings.dayString(for: yesterday)
        if let yesterdayStats = history[yesterdayKey], yesterdayStats.totalUnlocks > 0 {
            let deltaValue = Double(mindfulUnlocks - yesterdayStats.totalUnlocks) / Double(yesterdayStats.totalUnlocks)
            unlockDelta = deltaValue
        } else {
            unlockDelta = nil
        }

        perfectDays = SharedSettings.consecutiveUnlockFreeDays()
    }
}

#Preview {
    ProfileView()
}
