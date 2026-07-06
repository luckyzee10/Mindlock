import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

struct OnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    @State private var isAnimating = false
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    
    // User survey data
    @State private var dailyUsageHours: Double = 0
    @State private var userAge: Int = 0
    @State private var dailyGoalHours: Double = 2
    @State private var selectedGoal: OnboardingGoal?
    @State private var onboardingSelection = FamilyActivitySelection()
    @State private var onboardingLimitMinutesByToken: [String: Int] = [:]
    @State private var onboardingBlockStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var onboardingBlockEnd = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var onboardingBlockDays: Set<Int> = Set([2, 3, 4, 5, 6])
    @State private var setupError: String?
    
    private var pages: [OnboardingPage] {
        OnboardingPage.pages(for: selectedGoal?.setupPath)
    }
    
    var body: some View {
        ZStack {
            DesignSystem.AppBackground()
            
            VStack(spacing: 0) {
                // Pages
                ZStack {
                    onboardingPageView(for: pages[currentPage])
                        .id(currentPage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                
                // Navigation dots removed per design
                
                // Navigation buttons (only show for non-interactive pages, and not on final inspire screen)
                if !pages[currentPage].isInteractivePage && pages[currentPage].title != "Stay Mindful" {
                    if currentPage == 0 {
                        // Centered primary button on the first page, labeled "Continue"
                        HStack {
                            Spacer()
                            Button("Continue") {
                                withAnimation(DesignSystem.Animation.gentle) {
                                    currentPage += 1
                                }
                            }
                            .mindLockButton(style: .primary)
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    } else {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Spacer()

                            Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                                withAnimation(DesignSystem.Animation.gentle) {
                                    if currentPage == pages.count - 1 {
                                        // Save user preferences before completing
                                        saveUserPreferences()
                                        onComplete()
                                    } else {
                                        currentPage += 1
                                    }
                                }
                            }
                            .mindLockButton(style: .primary)
                            .frame(width: currentPage == pages.count - 1 ? nil : 100)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingPageView(for page: OnboardingPage) -> some View {
        if page.isPermissionPage {
            ScreenTimePermissionView(
                page: page,
                screenTimeManager: screenTimeManager,
                onContinue: advancePage
            )
        } else if page.isUsageQuestionPage {
            UsageQuestionView(
                page: page,
                selectedHours: $dailyUsageHours,
                onContinue: advancePage
            )
        } else if page.isAgeQuestionPage {
            AgeQuestionView(
                page: page,
                selectedAge: $userAge,
                onContinue: advancePage
            )
        } else if page.isImpactPage {
            LifetimeImpactView(
                page: page,
                dailyUsageHours: dailyUsageHours,
                userAge: userAge,
                onContinue: advancePage
            )
        } else if page.isConceptPage {
            ConceptExplanationView(
                page: page,
                onContinue: advancePage
            )
        } else if page.isGoalChoicePage {
            OnboardingGoalChoiceView(
                page: page,
                selectedGoal: $selectedGoal,
                onContinue: advancePage
            )
        } else if page.isGoalSettingPage {
            GoalSettingView(
                page: page,
                dailyUsageHours: dailyUsageHours,
                dailyGoalHours: $dailyGoalHours,
                onContinue: advancePage
            )
        } else if let setupStep = page.setupStep {
            setupStepView(for: page, setupStep: setupStep)
        } else if page.isAnimatedLimitsIntroPage {
            AnimatedLimitsIntroView(
                page: page,
                onContinue: advancePage
            )
        } else if page.isTimeLimitPage {
            // No longer used: app selection now lives inside AnimatedLimitsIntroView
            EmptyView()
        } else if page.title == "Stay Mindful" {
            FinalInspireView(
                page: page,
                dailyUsageHours: dailyUsageHours,
                dailyGoalHours: dailyGoalHours,
                onContinue: {
                    withAnimation(DesignSystem.Animation.gentle) {
                        saveUserPreferences()
                        onComplete()
                    }
                }
            )
        } else {
            staticOnboardingView(for: page)
        }
    }
    
    private func saveUserPreferences() {
        // Save user selections to UserDefaults or Core Data
        UserDefaults.standard.set(dailyUsageHours, forKey: "dailyUsageHours")
        UserDefaults.standard.set(userAge, forKey: "userAge")
        UserDefaults.standard.set(dailyGoalHours, forKey: "dailyGoalHours")
        UserDefaults.standard.set(dailyGoalHours * 7, forKey: "weeklyGoalHours")
        if let selectedGoal {
            UserDefaults.standard.set(selectedGoal.rawValue, forKey: "onboardingMainGoal")
            UserDefaults.standard.set(selectedGoal.setupPath.rawValue, forKey: "onboardingSetupPath")
        }
        // Update ScreenTimeManager with selected apps (already handled by the manager)
        print("💾 Saved user preferences")
    }

    @ViewBuilder
    private func setupStepView(for page: OnboardingPage, setupStep: OnboardingSetupStep) -> some View {
        switch setupStep {
        case .simpleLimitApps:
            OnboardingAppSelectionStepView(
                page: page,
                selection: $onboardingSelection,
                mode: .simpleLimits,
                onContinue: advancePage
            )
        case .simpleLimitSettings:
            OnboardingLimitSettingsStepView(
                page: page,
                selection: onboardingSelection,
                limitMinutesByToken: $onboardingLimitMinutesByToken,
                error: $setupError,
                onContinue: saveSimpleLimits
            )
        case .timeBlockApps:
            OnboardingAppSelectionStepView(
                page: page,
                selection: $onboardingSelection,
                mode: .timeBlock,
                onContinue: advancePage
            )
        case .timeBlockSchedule:
            OnboardingTimeBlockScheduleStepView(
                page: page,
                selection: onboardingSelection,
                start: $onboardingBlockStart,
                end: $onboardingBlockEnd,
                selectedDays: $onboardingBlockDays,
                error: $setupError,
                onContinue: saveTimeBlock
            )
        }
    }

    private func advancePage() {
        setupError = nil
        withAnimation(DesignSystem.Animation.gentle) {
            currentPage += 1
        }
    }

    private func saveSimpleLimits() {
        setupError = nil
        let tokens = onboardingSelection.applicationTokens
        guard !tokens.isEmpty else {
            setupError = "Select at least one app to continue."
            return
        }

        screenTimeManager.updateSelectedApps(onboardingSelection, reason: "onboarding simple limits")
        for token in tokens {
            let minutes = onboardingLimitMinutesByToken[token.identifier] ?? 30
            DailyLimitsManager.shared.setLimitImmediate(for: token, limit: TimeInterval(minutes * 60))
        }
        advancePage()
    }

    private func saveTimeBlock() {
        setupError = nil
        guard !onboardingSelection.applicationTokens.isEmpty else {
            setupError = "Select at least one app to continue."
            return
        }

        let calendar = Calendar.current
        let sh = calendar.component(.hour, from: onboardingBlockStart)
        let sm = calendar.component(.minute, from: onboardingBlockStart)
        let eh = calendar.component(.hour, from: onboardingBlockEnd)
        let em = calendar.component(.minute, from: onboardingBlockEnd)
        let minutes = (eh * 60 + em) - (sh * 60 + sm)

        guard minutes >= 60 else {
            setupError = "Time blocks must be at least 1 hour."
            return
        }

        guard !onboardingBlockDays.isEmpty else {
            setupError = "Select at least one day."
            return
        }

        screenTimeManager.updateSelectedApps(onboardingSelection, reason: "onboarding time block")
        let block = SharedSettings.TimeBlock(
            id: UUID().uuidString,
            name: "Focus Time",
            startHour: sh,
            startMinute: sm,
            endHour: eh,
            endMinute: em,
            daysOfWeek: onboardingBlockDays,
            enabled: true
        )
        var blocks = SharedSettings.loadTimeBlocks()
        blocks.append(block)
        SharedSettings.saveTimeBlocks(blocks)
        screenTimeManager.refreshMonitoringSchedule(reason: "onboarding time block")
        screenTimeManager.enforceActiveTimeBlocksNow()
        advancePage()
    }
    
    private func staticOnboardingView(for page: OnboardingPage) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            Image(systemName: page.iconName)
                .font(.system(size: 80, weight: .semibold))
                .foregroundColor(page.accentColor)
                .padding()
                .background(
                    Circle()
                        .fill(page.accentColor.opacity(0.12))
                        .frame(width: 180, height: 180)
                )
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(page.title)
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

struct UsageQuestionView: View {
    let page: OnboardingPage
    @Binding var selectedHours: Double
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    // Use the maximum value in each range to maximize impact in the later stats screen.
    private let usageOptions = [
        (hours: 2.0, label: "Less than 2 hours", subtitle: "Light user"),      // max = 2
        (hours: 4.0, label: "2-4 hours", subtitle: "Average user"),             // max = 4
        (hours: 6.0, label: "5-6 hours", subtitle: "Heavy user"),               // max = 6
        (hours: 8.0, label: "7-8 hours", subtitle: "Very heavy user"),          // max = 8
        (hours: 10.0, label: "More than 8 hours", subtitle: "Extreme user")     // choose 10 as representative upper bound
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Illustration - Smaller to save space
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.2),
                                page.accentColor.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 120
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 45, weight: .medium))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            .padding(.bottom, DesignSystem.Spacing.md)
            
            // Content - Compact spacing
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(page.title)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text(page.description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)
            
            // Usage options - More compact
            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(usageOptions.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectedHours = option.hours
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onContinue()
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            
                            Spacer()
                            
                            if selectedHours == option.hours {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .font(.system(size: 18))
                            } else {
                                Circle()
                                    .stroke(DesignSystem.Colors.textTertiary, lineWidth: 2)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            selectedHours == option.hours 
                                ? DesignSystem.Colors.primary.opacity(0.1)
                                : DesignSystem.Colors.surface
                        )
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(
                                    selectedHours == option.hours 
                                        ? DesignSystem.Colors.primary 
                                        : Color.clear, 
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                    .animation(DesignSystem.Animation.gentle, value: selectedHours)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()
        }
        .padding(.top, 10)
        .onAppear {
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
        }
    }
}

struct AgeQuestionView: View {
    let page: OnboardingPage
    @Binding var selectedAge: Int
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    private let ageRange = Array(13...80)
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.2),
                                page.accentColor.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            
            // Content
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(page.title)
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .offset(y: textOpacity == 1.0 ? 0 : 20)
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text(page.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .opacity(textOpacity)
                    .offset(y: textOpacity == 1.0 ? 0 : 20)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                Picker("Age", selection: $selectedAge) {
                    ForEach(ageRange, id: \.self) { age in
                        Text("\(age)")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()
                .labelsHidden()

                Button("Continue") {
                    onContinue()
                }
                .mindLockButton(style: .primary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()
        }
        .onAppear {
            if selectedAge == 0 {
                selectedAge = 25
            }
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
        }
    }
}

struct LifetimeImpactView: View {
    let page: OnboardingPage
    let dailyUsageHours: Double
    let userAge: Int
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    @State private var statsOpacity: Double = 0.0
    @State private var ctaOpacity: Double = 0.0
    
    private var lifetimeStats: (years: Double, days: Double, percentage: Double) {
        let remainingYears = max(0, 80 - userAge) // Assume life expectancy of 80
        let totalHours = dailyUsageHours * 365 * Double(remainingYears)
        let totalDays = totalHours / 24
        let totalYears = totalDays / 365
        
        // Calculate percentage based on waking hours (16 hours/day, excluding 8 hours sleep)
        let wakingHoursPerDay = 16.0
        let totalWakingHours = wakingHoursPerDay * 365 * Double(remainingYears)
        let percentageOfWakingLife = (totalHours / totalWakingHours) * 100
        
        return (years: totalYears, days: totalDays, percentage: min(percentageOfWakingLife, 100))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Warning illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignSystem.Colors.warning.opacity(0.2),
                                DesignSystem.Colors.warning.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.warning)
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
            
            // Header text
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("At your current pace, you'll spend")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text("\(Int(lifetimeStats.days / 365 * 365)) full days")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
                
                Text("every year scrolling and tapping.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(1.0), value: textOpacity)
                
                Text("Over your lifetime, that adds up to")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DesignSystem.Spacing.lg)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(1.2), value: textOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            
            // Main impact reveal
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: 8) {
                    Text("\(String(format: "%.0f", lifetimeStats.years))")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("years")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .opacity(statsOpacity)
                .scaleEffect(statsOpacity == 1.0 ? 1.0 : 0.8)
                .animation(DesignSystem.Animation.spring.delay(1.8), value: statsOpacity)
                
                Text("of your precious time lost to endless scrolling.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(statsOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(2.2), value: statsOpacity)
                
                // Percentage reveal
                HStack(spacing: 4) {
                    Text("That's")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("\(String(format: "%.1f%%", lifetimeStats.percentage))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.error)
                    
                    Text("of your waking hours.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, DesignSystem.Spacing.md)
                .opacity(statsOpacity)
                .animation(DesignSystem.Animation.gentle.delay(2.4), value: statsOpacity)
                
                Text("Time you'll never get back.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .opacity(statsOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(2.6), value: statsOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            
            // Call to action
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Ready to reclaim your life?")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(ctaOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(2.7), value: ctaOpacity)
                
                Button("Start My Journey") {
                    onContinue()
                }
                .mindLockButton(style: .primary)
                .opacity(ctaOpacity)
                .animation(DesignSystem.Animation.gentle.delay(2.8), value: ctaOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .onAppear {
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    statsOpacity = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                withAnimation {
                    ctaOpacity = 1.0
                }
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
            statsOpacity = 0.0
            ctaOpacity = 0.0
        }
    }
}



struct ScreenTimePermissionView: View {
    let page: OnboardingPage
    @ObservedObject var screenTimeManager: ScreenTimeManager
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    @State private var isRequestingPermission = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSkipWarning = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.2),
                                page.accentColor.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            
            // Content
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(page.title)
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .offset(y: textOpacity == 1.0 ? 0 : 20)
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text(page.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .opacity(textOpacity)
                    .offset(y: textOpacity == 1.0 ? 0 : 20)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
                
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: DesignSystem.Spacing.md) {
                if screenTimeManager.authorizationStatus == .approved {
                    Button("Continue") {
                        onContinue()
                    }
                    .mindLockButton(style: .primary)
                } else if screenTimeManager.authorizationStatus == .denied {
                    Button("Open Settings") {
                        openSettings()
                    }
                    .mindLockButton(style: .primary)
                } else {
                    Button(isRequestingPermission ? "Requesting..." : "Enable Screen Time") {
                        requestPermission()
                    }
                    .mindLockButton(style: .primary)
                    .disabled(isRequestingPermission)
                    .opacity(isRequestingPermission ? 0.6 : 1.0)
                    
                    Button("Skip for now") {
                        showingSkipWarning = true
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                // Debug info (remove in production)
                // (Debug controls removed for production)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl) // Extra padding to avoid dot overlap
        }
        .onAppear {
            // Force refresh authorization status when view appears
            screenTimeManager.checkAuthorizationStatus()
            
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
        }
        .alert("Screen Time Required", isPresented: $showingSkipWarning) {
            Button("Enable Now") { requestPermission() }
            Button("Continue Anyway", role: .destructive) { onContinue() }
        } message: {
            Text("MindLock relies on Screen Time to monitor usage and block distracting apps. Without it, core features won’t work. You can enable Screen Time anytime in Settings.")
        }
        .alert("Permission Error", isPresented: $showingError) {
            Button("Try Again") {
                requestPermission()
            }
            Button("Skip", role: .cancel) {
                onContinue()
            }
            if screenTimeManager.authorizationStatus == .denied {
                Button("Open Settings") {
                    openSettings()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func requestPermission() {
        print("🔐 User tapped Enable Screen Time button")
        print("🔐 Current status: \(screenTimeManager.authorizationStatus)")
        
        isRequestingPermission = true
        
        Task {
            do {
                print("🔐 Calling requestAuthorization...")
                try await screenTimeManager.requestAuthorization()
                
                await MainActor.run {
                    isRequestingPermission = false
                    print("🔐 Authorization completed successfully")
                    print("🔐 New status: \(screenTimeManager.authorizationStatus)")
                    if screenTimeManager.authorizationStatus == .approved {
                        onContinue()
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    print("🔐 Authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Weekly Goal Setting View
struct GoalSettingView: View {
    let page: OnboardingPage
    let dailyUsageHours: Double
    @Binding var dailyGoalHours: Double
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    private let minimumGoal: Double = 0.5
    private let stepAmount: Double = 0.25
    private let maximumGoal: Double = 8.0
    
    private var dailyUsageDisplay: String {
        formatHours(dailyUsageHours)
    }
    
    private var weeklyUsageDisplay: String {
        formatHours(dailyUsageHours * 7)
    }
    
    private var weeklyGoalDisplay: String {
        formatHours(dailyGoalHours * 7)
    }
    
    private var regainedHoursPerWeek: Double {
        max((dailyUsageHours - dailyGoalHours) * 7, 0)
    }
    
    private var regainedDisplay: String {
        formatHours(regainedHoursPerWeek)
    }
    
    private var regainedMessage: String {
        if regainedHoursPerWeek <= 0.1 {
            return "Set a smaller goal to start saving real time."
        } else {
            return "You’ll gain back **\(regainedDisplay)** every week."
        }
    }
    
    private var sliderColor: Color {
        let ratio = min(max(dailyGoalHours / maximumGoal, 0), 1)
        let start = DesignSystem.Colors.success
        let end = DesignSystem.Colors.accent
        return Color(
            red: start.components.red + (end.components.red - start.components.red) * ratio,
            green: start.components.green + (end.components.green - start.components.green) * ratio,
            blue: start.components.blue + (end.components.blue - start.components.blue) * ratio
        )
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.18),
                                page.accentColor.opacity(0.04)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 140
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "target")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(page.title)
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text("You spend about **\(dailyUsageDisplay)** a day on your phone — that’s **\(weeklyUsageDisplay)** a week you’re not getting back. Set your daily usage goal and gain back control.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Daily usage goal")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    HStack {
                        Text(String(format: "%.1f h/day", dailyGoalHours))
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(sliderColor)
                        Spacer()
                        Text("Weekly total: \(weeklyGoalDisplay)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Slider(value: $dailyGoalHours, in: minimumGoal...maximumGoal, step: 0.25) {
                    Text("Daily Goal")
                }
                .tint(sliderColor)

                HStack {
                    Text("Adjust anytime in Setup.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                }

                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.success.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(DesignSystem.Colors.success.opacity(0.35), lineWidth: 1)
                        )
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.success)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stay on goal, gain back time")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(regainedMessage)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.success)
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            
            Button("Continue") {
                onContinue()
            }
            .mindLockButton(style: .primary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .onAppear {
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
            if dailyUsageHours > 0 {
                let recommended = max(minimumGoal + stepAmount, min(maximumGoal, dailyUsageHours * 0.75))
                if abs(dailyGoalHours - 2) < 0.01 || dailyGoalHours <= minimumGoal {
                    dailyGoalHours = recommended
                } else {
                    dailyGoalHours = min(max(dailyGoalHours, minimumGoal + stepAmount), maximumGoal)
                }
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
        }
    }
    
    private func formatHours(_ value: Double) -> String {
        if value >= 24 {
            return String(format: "%.0f h", value)
        } else {
            return String(format: "%.1f h", value)
        }
    }
}

struct ConceptExplanationView: View {
    let page: OnboardingPage
    let onContinue: () -> Void

    @State private var showButton = false
    @State private var pulse = false
    @State private var visibleStepCount = 0
    @State private var visibleExampleCount = 0
    @State private var conceptStage: ConceptStage = .overview
    @State private var showTxt1 = false
    @State private var showCircle = false
    @State private var showTxt2 = false
    @State private var showPaywall = false
    @State private var shouldContinueAfterPaywall = false
    @State private var selectedUnlockMechanism = SharedSettings.preferredUnlockMechanism()

    private let subheadText = "MindLock turns your daily focus into healthier unlock habits."
    private let explainerText = "How it works is simple."
    private enum ConceptStage { case overview, examples }

    private let steps: [(String, String, String)] = [
        ("Set your limits", "Choose the apps and times MindLock should protect.", "lock.fill"),
        ("Stay accountable", "When an app is shielded, MindLock makes you pause before unlocking.", "clock.arrow.circlepath"),
        ("Earn breaks with movement", "Complete quick exercises to unlock more time when you need it.", "figure.strengthtraining.traditional")
    ]

    private let unlockOptions: [(SharedSettings.UnlockMechanism, String, String, String)] = [
        (.mindfulWait, "30s", "Mindful wait", "Pause, breathe, then unlock more time."),
        (.pushups, "5", "Pushups", "Earn your unlock with 5 pushups."),
        (.squats, "10", "Squats", "Earn your unlock with 10 squats.")
    ]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if conceptStage == .overview {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text(page.title)
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .opacity(showTxt1 ? 1 : 0)

                            Text(subheadText)
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .opacity(showTxt1 ? 1 : 0)

                            Text(explainerText)
                                .font(DesignSystem.Typography.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .opacity(showTxt1 ? 1 : 0)
                        }

                        ZStack {
                            Circle()
                                .stroke(DesignSystem.Colors.success.opacity(0.3), lineWidth: 12)
                                .scaleEffect(pulse ? 1.05 : 0.95)
                                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.success.opacity(0.35), DesignSystem.Colors.primary.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            VStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.success)
                                Text("Movement -> mindful unlocks")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                        .frame(width: 200, height: 200)
                        .opacity(showCircle ? 1 : 0)

                        VStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                if index < visibleStepCount {
                                    ImpactStepRow(iconName: step.2, title: step.0, detail: step.1)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("Choose your unlock method")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(showTxt2 ? 1 : 0)

                        UnlockMechanismVisual(mechanism: selectedUnlockMechanism)
                            .frame(height: 240)
                            .opacity(showTxt2 ? 1 : 0)
                    }
                    .padding(.top, DesignSystem.Spacing.lg)

                    Spacer(minLength: DesignSystem.Spacing.md)

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Array(unlockOptions.enumerated()), id: \.offset) { index, option in
                                if index < visibleExampleCount {
                                    UnlockMechanismOptionRow(
                                        marker: option.1,
                                        title: option.2,
                                        detail: option.3,
                                        isSelected: selectedUnlockMechanism == option.0
                                    ) {
                                        selectedUnlockMechanism = option.0
                                    }
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }

            if showButton {
                Button("Continue") {
                    continueTapped()
                }
                .mindLockButton(style: .primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
                .transition(.opacity)
            }
        }
        .onAppear { startSequence() }
        .onDisappear { resetSequence() }
        .sheet(isPresented: $showPaywall, onDismiss: {
            if shouldContinueAfterPaywall {
                shouldContinueAfterPaywall = false
                onContinue()
            }
        }) {
            UnlockPromptView()
        }
    }

    private func startSequence() {
        resetSequence()

        let textIntroDuration: Double = 0.5
        let textIntroHold: Double = 1.0
        let circleAnimationDuration: Double = 0.3
        let circleHold: Double = 1.0
        let listOneDuration: Double = 0.7

        schedule(after: 0.0) {
            withAnimation(.easeIn(duration: textIntroDuration)) {
                showTxt1 = true
            }
        }

        let circleStart = textIntroDuration + textIntroHold
        schedule(after: circleStart) {
            withAnimation(.easeIn(duration: circleAnimationDuration)) {
                showCircle = true
            }
            pulse = true
        }

        let listOneStart = circleStart + circleAnimationDuration + circleHold
        animateList(count: steps.count, startDelay: listOneStart, totalDuration: listOneDuration) { newCount in
            visibleStepCount = newCount
        }

        let buttonTime = listOneStart + listOneDuration + 0.5
        schedule(after: buttonTime) {
            withAnimation(.easeIn(duration: 0.4)) {
                showButton = true
            }
        }
    }

    private func resetSequence() {
        showTxt1 = false
        showCircle = false
        showTxt2 = false
        showButton = false
        pulse = false
        visibleStepCount = 0
        visibleExampleCount = 0
        conceptStage = .overview
        shouldContinueAfterPaywall = false
        selectedUnlockMechanism = SharedSettings.preferredUnlockMechanism()
    }

    private func continueTapped() {
        switch conceptStage {
        case .overview:
            showButton = false
            pulse = false
            withAnimation(.easeInOut(duration: 0.25)) {
                showTxt1 = false
                showCircle = false
                visibleStepCount = 0
            }
            schedule(after: 0.25) {
                conceptStage = .examples
                showTxt2 = false
                visibleExampleCount = 0
                withAnimation(.easeIn(duration: 0.35)) {
                    showTxt2 = true
                }
                animateList(count: unlockOptions.count, startDelay: 0.35, totalDuration: 0.7) { newCount in
                    visibleExampleCount = newCount
                }
                schedule(after: 1.2) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showButton = true
                    }
                }
            }
        case .examples:
            SharedSettings.setPreferredUnlockMechanism(selectedUnlockMechanism)
            shouldContinueAfterPaywall = true
            showPaywall = true
        }
    }

    private func schedule(after delay: Double, perform: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: perform)
    }

    private func animateList(count: Int, startDelay: Double, totalDuration: Double, update: @escaping (Int) -> Void) {
        guard count > 0 else { return }
        let interval = count > 1 ? totalDuration / Double(count - 1) : 0
        schedule(after: startDelay) {
            withAnimation(.easeIn(duration: 0.25)) {
                update(1)
            }
        }
        if count > 1 {
            for index in 1..<count {
                schedule(after: startDelay + interval * Double(index)) {
                    withAnimation(.easeIn(duration: 0.25)) {
                        update(index + 1)
                    }
                }
            }
        }
    }
}
// MARK: - Final Inspire View (Stay Mindful replacement)
struct FinalInspireView: View {
    let page: OnboardingPage
    let dailyUsageHours: Double
    let dailyGoalHours: Double
    let onContinue: () -> Void

    @State private var textOpacity: Double = 0.0
    @State private var bullet1Opacity: Double = 0.0
    @State private var bullet2Opacity: Double = 0.0
    @State private var bullet3Opacity: Double = 0.0
    @State private var pulse: Bool = false

    private var dailyReduction: Double {
        max(0, dailyUsageHours - dailyGoalHours)
    }
    private var weeklyGain: Double { dailyReduction * 7 }
    private var yearlyGain: Double { dailyReduction * 365 }

    private func formatHours(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let unit = abs(rounded - 1.0) < 0.001 ? "hour" : "hours"
        if rounded == floor(rounded) {
            return "\(Int(rounded)) \(unit)"
        }
        return String(format: "%.1f %@", rounded, unit)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.xxl) {
                Text("Based on your data, if you stay consistent:")
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "target").foregroundColor(DesignSystem.Colors.success)
                        Text("💪 You’ll reduce screen time by \(formatHours(dailyReduction)) each day.")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .opacity(bullet1Opacity)
                            .offset(y: bullet1Opacity == 1 ? 0 : 8)
                    }
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "target").foregroundColor(DesignSystem.Colors.success)
                        Text("🕚 Gain back \(formatHours(weeklyGain)) each week")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .opacity(bullet2Opacity)
                            .offset(y: bullet2Opacity == 1 ? 0 : 8)
                    }
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "target").foregroundColor(DesignSystem.Colors.success)
                        Text("📈 That’s \(formatHours(yearlyGain)) a year!")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .opacity(bullet3Opacity)
                            .offset(y: bullet3Opacity == 1 ? 0 : 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Text("Ready to lock in?")
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DesignSystem.Spacing.lg)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .opacity(textOpacity)

            Spacer()

            // Pulsing lock inside a green circle
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.success.opacity(0.35), lineWidth: 10)
                    .scaleEffect(pulse ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(DesignSystem.Colors.success.opacity(0.15))
                    .frame(width: 160, height: 160)

                Image(systemName: "lock.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.success)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)

            Text("Tap to continue")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.bottom, DesignSystem.Spacing.xxl)

        }
        .contentShape(Rectangle())
        .onTapGesture { onContinue() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { textOpacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.5)) { bullet1Opacity = 1.0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.5)) { bullet2Opacity = 1.0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) { bullet3Opacity = 1.0 }
            }
            pulse = true
        }
    }
}



private struct ImpactStepRow: View {
    let iconName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.success.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.success)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(detail)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.md)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

private struct ImpactExampleRow: View {
    let emoji: String
    let text: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(emoji)
                .font(.system(size: 20))
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.md)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

private struct UnlockMechanismVisual: View {
    let mechanism: SharedSettings.UnlockMechanism

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary.opacity(0.20), DesignSystem.Colors.success.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 210, height: 210)

            Circle()
                .stroke(DesignSystem.Colors.primary.opacity(0.18), lineWidth: 2)
                .frame(width: 184, height: 184)

            switch mechanism {
            case .mindfulWait:
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            case .pushups, .squats:
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: mechanism)
    }
}

private struct UnlockMechanismOptionRow: View {
    let marker: String
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Text(marker)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.background.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.body.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(detail)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? DesignSystem.Colors.primary.opacity(0.14) : DesignSystem.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(isSelected ? DesignSystem.Colors.primary.opacity(0.8) : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Animated Limits Intro View (Block List Selection)
struct AnimatedLimitsIntroView: View {
    let page: OnboardingPage
    let onContinue: () -> Void

    @State private var showPicker = false
    @State private var localSelection = FamilyActivitySelection()
    @State private var showSelectedList = false
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared

    private let iconSize: CGFloat = 56

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer().frame(height: DesignSystem.Spacing.sm)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Choose your block list.")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("These are the apps MindLock will pause whenever you run a Time Block.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            ZStack {
                if showSelectedList {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Array(localSelection.applicationTokens).sorted { $0.identifier < $1.identifier }, id: \.identifier) { token in
                                BlockListAppRow(applicationToken: token)
                            }
                            Color.clear.frame(height: 140)
                        }
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.black, location: 0.0),
                                .init(color: Color.black, location: 0.82),
                                .init(color: Color.clear, location: 1.0)
                            ]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                } else {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Text("Need ideas?")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        HStack(spacing: DesignSystem.Spacing.xl) {
                            appIconWithLimit(name: "facebook", label: "30m")
                            appIconWithLimit(name: "instagram", label: "20m")
                            appIconWithLimit(name: "tik tok", label: "1h")
                        }

                        Text("Start with the apps that drain your focus the most.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg)
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.surface.opacity(0.4), lineWidth: 1)
                    )
                }
            }
            .frame(height: 320)

            Spacer()

            VStack(spacing: DesignSystem.Spacing.md) {
                Button(showSelectedList ? "Add another app" : "Select apps to block  +") {
                    showPicker = true
                }
                .mindLockButton(style: .primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                if showSelectedList {
                    Button("Continue") {
                        screenTimeManager.updateSelectedApps(localSelection, reason: "onboarding block list")
                        onContinue()
                    }
                    .mindLockButton(style: .primary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .familyActivityPicker(isPresented: $showPicker, selection: $localSelection)
        .onChange(of: localSelection.applicationTokens) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                showSelectedList = !newValue.isEmpty
            }
        }
        .onAppear {
            localSelection = screenTimeManager.selectedApps
            showSelectedList = !localSelection.applicationTokens.isEmpty
        }
    }

    private func appIconWithLimit(name: String, label: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            loadIcon(name)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }

    private func loadIcon(_ name: String) -> Image {
        if let ui = UIImage(named: name) { return Image(uiImage: ui) }
        if name == "tik tok", let ui = UIImage(named: "tiktok") { return Image(uiImage: ui) }
        return Image(systemName: "app")
    }
}

struct OnboardingGoalChoiceView: View {
    let page: OnboardingPage
    @Binding var selectedGoal: OnboardingGoal?
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer().frame(height: DesignSystem.Spacing.lg)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(page.title)
                        .font(DesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(page.description)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(OnboardingGoal.allCases) { goal in
                        Button {
                            selectedGoal = goal
                            UserDefaults.standard.set(goal.rawValue, forKey: "onboardingMainGoal")
                            UserDefaults.standard.set(goal.setupPath.rawValue, forKey: "onboardingSetupPath")
                            onContinue()
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: goal.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(goal.setupPath == .timeBlock ? DesignSystem.Colors.warning : DesignSystem.Colors.primary)
                                    .frame(width: 28)

                                Text(goal.title)
                                    .font(DesignSystem.Typography.body.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg)
                            .cornerRadius(DesignSystem.CornerRadius.lg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}

enum OnboardingAppSelectionMode {
    case simpleLimits
    case timeBlock
}

struct OnboardingAppSelectionStepView: View {
    let page: OnboardingPage
    @Binding var selection: FamilyActivitySelection
    let mode: OnboardingAppSelectionMode
    let onContinue: () -> Void

    @State private var showPicker = false
    private var selectedCount: Int { selection.applicationTokens.count }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer().frame(height: DesignSystem.Spacing.sm)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(page.title)
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            selectionPreview

            Spacer()

            VStack(spacing: DesignSystem.Spacing.md) {
                Button(selectedCount == 0 ? "Select apps" : "Add or remove apps") {
                    showPicker = true
                }
                .mindLockButton(style: .primary)

                Button("Continue") { onContinue() }
                .mindLockButton(style: .primary)
                .disabled(selectedCount == 0)
                .opacity(selectedCount == 0 ? 0.45 : 1)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .padding(.top, DesignSystem.Spacing.lg)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
    }

    private var selectionPreview: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if selectedCount == 0 {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: mode == .simpleLimits ? "timer" : "rectangle.stack.badge.person.crop")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)

                    Text(mode == .simpleLimits
                         ? "Start with the apps you open on autopilot."
                         : "Build the list MindLock will shield during your focus window.")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg)
                .cornerRadius(DesignSystem.CornerRadius.lg)
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(Array(selection.applicationTokens).sorted { $0.identifier < $1.identifier }, id: \.identifier) { token in
                            BlockListAppRow(applicationToken: token)
                        }
                    }
                }
                .frame(height: 330)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.black, location: 0.0),
                            .init(color: Color.black, location: 0.94),
                            .init(color: Color.clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

struct OnboardingLimitSettingsStepView: View {
    let page: OnboardingPage
    let selection: FamilyActivitySelection
    @Binding var limitMinutesByToken: [String: Int]
    @Binding var error: String?
    let onContinue: () -> Void

    private let minuteOptions = [15, 30, 45, 60, 90, 120]
    private var tokens: [ApplicationToken] {
        Array(selection.applicationTokens).sorted { $0.identifier < $1.identifier }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(page.title)
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            appLimitList

            if let error {
                Text(error)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            Button("Save limits") { onContinue() }
                .mindLockButton(style: .primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .padding(.top, DesignSystem.Spacing.xl)
        .onAppear {
            for token in tokens where limitMinutesByToken[token.identifier] == nil {
                limitMinutesByToken[token.identifier] = 30
            }
        }
    }

    private var appLimitList: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(tokens, id: \.identifier) { token in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(DesignSystem.Typography.body.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Menu {
                            ForEach(minuteOptions, id: \.self) { minutes in
                                Button("\(minutes) minutes") {
                                    limitMinutesByToken[token.identifier] = minutes
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(limitMinutes(for: token))m")
                                    .font(DesignSystem.Typography.callout.weight(.bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(DesignSystem.Colors.primary)
                            .cornerRadius(14)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg)
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, 80)
        }
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.0),
                    .init(color: Color.black, location: 0.9),
                    .init(color: Color.clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func limitMinutes(for token: ApplicationToken) -> Int {
        limitMinutesByToken[token.identifier] ?? 30
    }
}

struct OnboardingTimeBlockScheduleStepView: View {
    let page: OnboardingPage
    let selection: FamilyActivitySelection
    @Binding var start: Date
    @Binding var end: Date
    @Binding var selectedDays: Set<Int>
    @Binding var error: String?
    let onContinue: () -> Void

    private var selectedCount: Int { selection.applicationTokens.count }
    private let dayOptions = [(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(page.title)
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            scheduleCard
            selectedSummary

            if let error {
                Text(error)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            Button("Create time block") { onContinue() }
                .mindLockButton(style: .primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .padding(.top, DesignSystem.Spacing.xl)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Focus window")
                .font(DesignSystem.Typography.callout.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.md) {
                DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.Colors.background.opacity(0.55))
                    .cornerRadius(DesignSystem.CornerRadius.md)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.Colors.background.opacity(0.55))
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(dayOptions, id: \.0) { day, label in
                    Button {
                        toggleDay(day)
                    } label: {
                        Text(label)
                            .font(DesignSystem.Typography.caption.weight(.bold))
                            .foregroundColor(selectedDays.contains(day) ? .white : DesignSystem.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(selectedDays.contains(day) ? DesignSystem.Colors.primary : DesignSystem.Colors.background.opacity(0.75))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text(daysSummary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 0.55)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var daysSummary: String {
        if selectedDays == Set(1...7) { return "Every day" }
        if selectedDays == Set([2, 3, 4, 5, 6]) { return "Weekdays" }
        if selectedDays == Set([1, 7]) { return "Weekends" }
        return "\(selectedDays.count) day\(selectedDays.count == 1 ? "" : "s")"
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
        error = nil
    }

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Block list")
                    .font(DesignSystem.Typography.callout.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(selectedCount) apps")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            HStack(spacing: -8) {
                ForEach(Array(selection.applicationTokens).sorted { $0.identifier < $1.identifier }.prefix(3), id: \.identifier) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 34)
                        .background(DesignSystem.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if selectedCount > 3 {
                    Text("+\(selectedCount - 3)")
                        .font(DesignSystem.Typography.caption.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(DesignSystem.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 0.55)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

struct ConceptCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(icon)
                .font(.system(size: 32))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.md)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Data Model
enum OnboardingSetupPath: String {
    case simpleLimits
    case timeBlock
}

enum OnboardingSetupStep {
    case simpleLimitApps
    case simpleLimitSettings
    case timeBlockApps
    case timeBlockSchedule
}

enum OnboardingGoal: String, CaseIterable, Identifiable {
    case present
    case productiveHours
    case lightExercise
    case overallPhoneUsage
    case work
    case socialMedia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .present:
            return "Be more present throughout the day?"
        case .productiveHours:
            return "Limit distracting app use during productive hours?"
        case .lightExercise:
            return "Integrate light exercise into your daily habits?"
        case .overallPhoneUsage:
            return "Limit overall phone usage?"
        case .work:
            return "Use your phone less during work?"
        case .socialMedia:
            return "Reduce time on social media?"
        }
    }

    var iconName: String {
        switch self {
        case .present:
            return "person.2.fill"
        case .productiveHours:
            return "briefcase.fill"
        case .lightExercise:
            return "figure.strengthtraining.traditional"
        case .overallPhoneUsage:
            return "iphone.slash"
        case .work:
            return "laptopcomputer"
        case .socialMedia:
            return "bubble.left.and.bubble.right.fill"
        }
    }

    var setupPath: OnboardingSetupPath {
        switch self {
        case .productiveHours, .work:
            return .timeBlock
        case .present, .lightExercise, .overallPhoneUsage, .socialMedia:
            return .simpleLimits
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let iconName: String
    let accentColor: Color
    let isPermissionPage: Bool
    let isUsageQuestionPage: Bool
    let isAgeQuestionPage: Bool
    let isImpactPage: Bool
    let isTimeLimitPage: Bool
    let isGoalSettingPage: Bool
    let isConceptPage: Bool
    let isAnimatedLimitsIntroPage: Bool
    let isGoalChoicePage: Bool
    let setupStep: OnboardingSetupStep?

    init(
        title: String,
        description: String,
        iconName: String,
        accentColor: Color,
        isPermissionPage: Bool = false,
        isUsageQuestionPage: Bool = false,
        isAgeQuestionPage: Bool = false,
        isImpactPage: Bool = false,
        isTimeLimitPage: Bool = false,
        isGoalSettingPage: Bool = false,
        isConceptPage: Bool = false,
        isAnimatedLimitsIntroPage: Bool = false,
        isGoalChoicePage: Bool = false,
        setupStep: OnboardingSetupStep? = nil
    ) {
        self.title = title
        self.description = description
        self.iconName = iconName
        self.accentColor = accentColor
        self.isPermissionPage = isPermissionPage
        self.isUsageQuestionPage = isUsageQuestionPage
        self.isAgeQuestionPage = isAgeQuestionPage
        self.isImpactPage = isImpactPage
        self.isTimeLimitPage = isTimeLimitPage
        self.isGoalSettingPage = isGoalSettingPage
        self.isConceptPage = isConceptPage
        self.isAnimatedLimitsIntroPage = isAnimatedLimitsIntroPage
        self.isGoalChoicePage = isGoalChoicePage
        self.setupStep = setupStep
    }
    
    var isInteractivePage: Bool {
        return isPermissionPage || isUsageQuestionPage || isAgeQuestionPage || isImpactPage || isTimeLimitPage || isGoalSettingPage || isConceptPage || isAnimatedLimitsIntroPage || isGoalChoicePage || setupStep != nil
    }
    
    static func pages(for setupPath: OnboardingSetupPath?) -> [OnboardingPage] {
        let selectedSetupPath = setupPath ?? .simpleLimits
        return [
        OnboardingPage(
            title: "Welcome to MindLock",
            description: "Turn better habits into more app time with limits, movement, and mindful unlocks.",
            iconName: "lock.fill",
            accentColor: DesignSystem.Colors.primary
        ),
        OnboardingPage(
            title: "How much time do you spend on your phone daily?",
            description: "This helps us understand your current habits.",
            iconName: "iphone",
            accentColor: DesignSystem.Colors.primary,
            isUsageQuestionPage: true,
        ),
        OnboardingPage(
            title: "What's your age range?",
            description: "This helps us calculate your lifetime digital usage.",
            iconName: "person.fill",
            accentColor: DesignSystem.Colors.primary,
            isAgeQuestionPage: true,
        ),
        OnboardingPage(
            title: "Your Digital Future",
            description: "Here's what your current usage means for your lifetime.",
            iconName: "exclamationmark.triangle.fill",
            accentColor: DesignSystem.Colors.warning,
            isImpactPage: true,
        ),
        OnboardingPage(
            title: "Enable Screen Time",
            description: "MindLock needs Screen Time access to monitor your app usage and enforce healthy digital boundaries.",
            iconName: "iphone.and.arrow.forward",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: true,
        ),
        OnboardingPage(
            title: "What is your main goal?",
            description: "This will help us tailor your experience.",
            iconName: "target",
            accentColor: DesignSystem.Colors.primary,
            isGoalChoicePage: true
        ),
        setupAppSelectionPage(for: selectedSetupPath),
        setupDetailPage(for: selectedSetupPath),
        OnboardingPage(
            title: "Earn Your Breaks",
            description: "Choose how you want to unlock extra time.",
            iconName: "figure.strengthtraining.traditional",
            accentColor: DesignSystem.Colors.success,
            isConceptPage: true,
        ),
        OnboardingPage(
            title: "Set Your Daily Goal",
            description: "Choose a target that keeps you honest. You can always adjust this later.",
            iconName: "target",
            accentColor: DesignSystem.Colors.primary,
            isGoalSettingPage: true,
        ),
        OnboardingPage(
            title: "Stay Mindful",
            description: "Get insights into your usage patterns and make intentional choices about your digital time.",
            iconName: "chart.line.uptrend.xyaxis",
            accentColor: DesignSystem.Colors.accent
        )
    ]
    }

    private static func setupAppSelectionPage(for setupPath: OnboardingSetupPath) -> OnboardingPage {
        OnboardingPage(
            title: setupPath == .simpleLimits ? "Choose apps to limit" : "Choose your block list",
            description: setupPath == .simpleLimits
                ? "Pick the apps where you want a daily guardrail."
                : "Pick the apps MindLock should shield during your focus window.",
            iconName: setupPath == .simpleLimits ? "apps.iphone" : "rectangle.stack.badge.person.crop",
            accentColor: DesignSystem.Colors.primary,
            setupStep: setupPath == .simpleLimits ? .simpleLimitApps : .timeBlockApps
        )
    }

    private static func setupDetailPage(for setupPath: OnboardingSetupPath) -> OnboardingPage {
        OnboardingPage(
            title: setupPath == .simpleLimits ? "Set your app limits" : "Create your schedule",
            description: setupPath == .simpleLimits
                ? "Review each app and adjust how much time feels right."
                : "Choose when MindLock should protect your block list.",
            iconName: setupPath == .simpleLimits ? "slider.horizontal.3" : "calendar.badge.clock",
            accentColor: DesignSystem.Colors.primary,
            setupStep: setupPath == .simpleLimits ? .simpleLimitSettings : .timeBlockSchedule
        )
    }
}

private extension Color {
    struct RGBComponents {
        let red: Double
        let green: Double
        let blue: Double
    }
    
    var components: RGBComponents {
        #if os(iOS)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBComponents(red: Double(r), green: Double(g), blue: Double(b))
        #else
        return RGBComponents(red: 0, green: 0, blue: 0)
        #endif
    }

    // (logos live in Assets.xcassets; Color has no logo mapping)
}

// Visual fades at the top/bottom edges to hint scrollability
private struct EdgeFades: View {
    var body: some View {
        VStack {
            LinearGradient(
                gradient: Gradient(colors: [DesignSystem.Colors.background, DesignSystem.Colors.background.opacity(0)]),
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 16)
            Spacer()
            LinearGradient(
                gradient: Gradient(colors: [DesignSystem.Colors.background.opacity(0), DesignSystem.Colors.background]),
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 16)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {
        print("Onboarding completed")
    })
} 
