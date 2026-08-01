import SwiftUI

struct JourneyTrackerView: View {
    @StateObject private var viewModel = JourneyTrackerViewModel()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    hero
                    ForEach(viewModel.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.AppBackground())
            .navigationTitle("Journey")
        }
        .onAppear { viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.analyticsUpdatedNotification)) { _ in
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.learningLanguageChangedNotification)) { _ in
            viewModel.refresh()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.language.displayName.uppercased())
                        .font(DesignSystem.Typography.caption.weight(.heavy))
                        .foregroundColor(.white.opacity(0.75))
                    Text("Learning Journey")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)
                    Text("\(viewModel.completedLessonCount) of \(viewModel.totalLessonCount) lessons complete")
                        .font(DesignSystem.Typography.callout.weight(.semibold))
                        .foregroundColor(.white.opacity(0.86))
                }
                Spacer()
                Image(systemName: "flag.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: proxy.size.width * viewModel.courseProgress)
                }
            }
            .frame(height: 10)

            HStack(spacing: DesignSystem.Spacing.lg) {
                journeyMetric("\(viewModel.summary.weeklyXP)", "XP this week")
                journeyMetric("\(viewModel.summary.level)", "Level")
                journeyMetric("\(viewModel.currentSectionTitle)", "Now")
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.62, blue: 0.31),
                    Color(red: 0.08, green: 0.42, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous))
        .shadow(color: DesignSystem.Colors.primary.opacity(0.26), radius: 24, x: 0, y: 14)
    }

    private func journeyMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(DesignSystem.Typography.headline.weight(.heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionView(_ section: LanguageSection) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader(section)

            VStack(spacing: 0) {
                ForEach(Array(section.lessons.enumerated()), id: \.element.id) { index, lesson in
                    lessonNode(lesson, index: index)
                    if index < section.lessons.count - 1 {
                        connector(after: lesson)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }

    private func sectionHeader(_ section: LanguageSection) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SECTION \(section.unitNumber), UNIT 1")
                    .font(DesignSystem.Typography.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.82))
                Text(section.title)
                    .font(DesignSystem.Typography.title3.weight(.heavy))
                    .foregroundColor(.white)
                Text(section.theme)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.white.opacity(0.76))
            }
            Spacer()
            Image(systemName: section.iconName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(DesignSystem.Spacing.lg)
        .background(sectionGradient(section.unitNumber))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func lessonNode(_ lesson: LanguageLesson, index: Int) -> some View {
        let state = viewModel.state(for: lesson)
        let alignment: Alignment = index.isMultiple(of: 2) ? .leading : .trailing

        return VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(nodeFill(state))
                    .frame(width: 86, height: 86)
                    .shadow(color: nodeShadow(state), radius: state == .current ? 18 : 8, x: 0, y: 8)

                Circle()
                    .stroke(nodeStroke(state), lineWidth: state == .current ? 5 : 2)
                    .frame(width: 98, height: 98)

                Image(systemName: nodeIcon(lesson, state: state))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(nodeIconColor(state))
            }

            Text(lesson.title)
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundColor(state == .locked ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 130)
        }
        .frame(width: 140)
        .frame(maxWidth: .infinity, alignment: alignment)
        .padding(.horizontal, 26)
        .padding(.vertical, 6)
    }

    private func connector(after lesson: LanguageLesson) -> some View {
        Rectangle()
            .fill(viewModel.completedLessonIDs.contains(lesson.id) ? DesignSystem.Colors.success.opacity(0.62) : Color.white.opacity(0.12))
            .frame(width: 5, height: 34)
            .clipShape(Capsule())
    }

    private func sectionGradient(_ unit: Int) -> LinearGradient {
        let colors: [Color]
        switch unit {
        case 1:
            colors = [Color(red: 0.25, green: 0.80, blue: 0.02), Color(red: 0.08, green: 0.64, blue: 0.04)]
        case 2:
            colors = [Color(red: 0.10, green: 0.50, blue: 0.95), Color(red: 0.35, green: 0.27, blue: 0.90)]
        case 3:
            colors = [Color(red: 0.94, green: 0.55, blue: 0.12), Color(red: 0.84, green: 0.28, blue: 0.18)]
        default:
            colors = [Color(red: 0.55, green: 0.28, blue: 0.92), Color(red: 0.85, green: 0.24, blue: 0.70)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func nodeFill(_ state: LessonNodeState) -> Color {
        switch state {
        case .completed: return DesignSystem.Colors.success
        case .current: return Color(red: 0.28, green: 0.78, blue: 0.04)
        case .locked: return Color.white.opacity(0.13)
        }
    }

    private func nodeStroke(_ state: LessonNodeState) -> Color {
        switch state {
        case .completed: return DesignSystem.Colors.success.opacity(0.55)
        case .current: return DesignSystem.Colors.success.opacity(0.85)
        case .locked: return Color.white.opacity(0.08)
        }
    }

    private func nodeShadow(_ state: LessonNodeState) -> Color {
        switch state {
        case .completed, .current: return DesignSystem.Colors.success.opacity(0.25)
        case .locked: return .clear
        }
    }

    private func nodeIcon(_ lesson: LanguageLesson, state: LessonNodeState) -> String {
        switch state {
        case .completed: return "checkmark"
        case .current: return "star.fill"
        case .locked: return lesson.iconName
        }
    }

    private func nodeIconColor(_ state: LessonNodeState) -> Color {
        switch state {
        case .completed, .current: return .white
        case .locked: return DesignSystem.Colors.textTertiary
        }
    }
}

private enum LessonNodeState {
    case completed
    case current
    case locked
}

private final class JourneyTrackerViewModel: ObservableObject {
    @Published var language: SharedSettings.LearningLanguage = SharedSettings.preferredLearningLanguage()
    @Published var sections: [LanguageSection] = []
    @Published var completedLessonIDs: Set<String> = []
    @Published var summary = SharedSettings.LanguageProgressSummary(totalXP: 0, weeklyXP: 0, practicedThisWeek: 0, correctThisWeek: 0, skillXP: [:])

    var totalLessonCount: Int {
        sections.reduce(0) { $0 + $1.lessons.count }
    }

    var completedLessonCount: Int {
        completedLessonIDs.count
    }

    var courseProgress: CGFloat {
        guard totalLessonCount > 0 else { return 0 }
        return CGFloat(min(Double(completedLessonCount) / Double(totalLessonCount), 1))
    }

    var currentSectionTitle: String {
        let currentLessonID = nextLesson?.id
        return sections.first { section in
            section.lessons.contains { $0.id == currentLessonID }
        }?.theme ?? "Complete"
    }

    private var orderedLessons: [LanguageLesson] {
        sections.flatMap(\.lessons)
    }

    private var nextLesson: LanguageLesson? {
        orderedLessons.first { !completedLessonIDs.contains($0.id) }
    }

    func refresh() {
        language = SharedSettings.preferredLearningLanguage()
        sections = LanguageLearningCatalog.sections(for: language)
        completedLessonIDs = SharedSettings.completedLanguageLessonIDs()
        summary = SharedSettings.languageProgressSummary()
    }

    func state(for lesson: LanguageLesson) -> LessonNodeState {
        if completedLessonIDs.contains(lesson.id) {
            return .completed
        }
        if lesson.id == nextLesson?.id {
            return .current
        }
        return .locked
    }
}

#Preview {
    JourneyTrackerView()
}
