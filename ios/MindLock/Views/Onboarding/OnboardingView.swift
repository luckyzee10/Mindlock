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
    @State private var selectedCharity: Charity?
    @State private var dailyGoalHours: Double = 2
    @State private var selectedPricingTier: PricingTier = .moderate
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if pages[index].isPermissionPage {
                            ScreenTimePermissionView(
                                page: pages[index],
                                screenTimeManager: screenTimeManager,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isUsageQuestionPage {
                            UsageQuestionView(
                                page: pages[index],
                                selectedHours: $dailyUsageHours,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isAgeQuestionPage {
                            AgeQuestionView(
                                page: pages[index],
                                selectedAge: $userAge,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isImpactPage {
                            LifetimeImpactView(
                                page: pages[index],
                                dailyUsageHours: dailyUsageHours,
                                userAge: userAge,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isCharityPage {
                            CharitySelectionView(
                                page: pages[index],
                                selectedCharity: $selectedCharity,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isConceptPage {
                            ConceptExplanationView(
                                page: pages[index],
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isGoalSettingPage {
                            GoalSettingView(
                                page: pages[index],
                                dailyUsageHours: dailyUsageHours,
                                dailyGoalHours: $dailyGoalHours,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isPricingTierPage {
                            PricingTierSelectionView(
                                page: pages[index],
                                selectedPricingTier: $selectedPricingTier,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isAnimatedLimitsIntroPage {
                            AnimatedLimitsIntroView(
                                page: pages[index],
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        currentPage += 1
                                    }
                                }
                            )
                            .tag(index)
                        } else if pages[index].isTimeLimitPage {
                            // No longer used: app selection now lives inside AnimatedLimitsIntroView
                            EmptyView().tag(index)
                        } else if pages[index].title == "Stay Mindful" {
                            FinalInspireView(
                                page: pages[index],
                                dailyUsageHours: dailyUsageHours,
                                dailyGoalHours: dailyGoalHours,
                                onContinue: {
                                    withAnimation(DesignSystem.Animation.gentle) {
                                        saveUserPreferences()
                                        onComplete()
                                    }
                                }
                            )
                            .tag(index)
                        } else {
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
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
    
    private func saveUserPreferences() {
        // Save user selections to UserDefaults or Core Data
        UserDefaults.standard.set(dailyUsageHours, forKey: "dailyUsageHours")
        UserDefaults.standard.set(userAge, forKey: "userAge")
        if let charity = selectedCharity {
            UserDefaults.standard.set(charity.id, forKey: "selectedCharityId")
        }
        UserDefaults.standard.set(dailyGoalHours, forKey: "dailyGoalHours")
        UserDefaults.standard.set(dailyGoalHours * 7, forKey: "weeklyGoalHours")
        UserDefaults.standard.set(selectedPricingTier.name, forKey: "selectedPricingTier")
        
        // Update ScreenTimeManager with selected apps (already handled by the manager)
        print("💾 Saved user preferences: \(selectedPricingTier.name) tier, \(selectedCharity?.name ?? "no charity")")
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
    
    // Use the earliest age in each range to maximize remaining lifetime in the stats screen.
    private let ageRanges = [
        (age: 13, label: "13-18", subtitle: "Teen"),
        (age: 19, label: "19-25", subtitle: "Young adult"),
        (age: 26, label: "26-35", subtitle: "Adult"),
        (age: 36, label: "36-45", subtitle: "Mid-life"),
        (age: 46, label: "46-55", subtitle: "Mature"),
        (age: 56, label: "56+", subtitle: "Senior")
    ]
    
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
            
            // Age options
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(ageRanges.enumerated()), id: \.offset) { index, ageRange in
                    Button(action: {
                        selectedAge = ageRange.age
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onContinue()
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(ageRange.label)
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            if selectedAge == ageRange.age {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                        .background(
                            selectedAge == ageRange.age 
                                ? DesignSystem.Colors.primary.opacity(0.1)
                                : DesignSystem.Colors.surface
                        )
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(
                                    selectedAge == ageRange.age 
                                        ? DesignSystem.Colors.primary 
                                        : Color.clear, 
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                    .animation(DesignSystem.Animation.gentle, value: selectedAge)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
        }
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
    let screenTimeManager: ScreenTimeManager
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
                
                // Permission status
                permissionStatusView
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
    
    private var debugStatusText: String {
        switch screenTimeManager.authorizationStatus {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
    
    private var permissionStatusView: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16, weight: .medium))
            
            Text(statusText)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(statusColor)
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(statusColor.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var statusIcon: String {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return DesignSystem.Colors.success
        case .denied:
            return DesignSystem.Colors.error
        case .notDetermined:
            return DesignSystem.Colors.warning
        @unknown default:
            return DesignSystem.Colors.error
        }
    }
    
    private var statusText: String {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return "Screen Time access granted ✅"
        case .denied:
            return "Screen Time access denied"
        case .notDetermined:
            return "Screen Time permission needed"
        @unknown default:
            return "Screen Time status unknown"
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

// MARK: - Real App Limit Card (App Store Compliant)
struct RealAppLimitCard: View {
    let applicationToken: ApplicationToken
    @Binding var timeLimit: Int
    
    private let timeLimitOptions = [10, 15, 20, 30, 45, 60, 90, 120, 180, 240] // Minutes
    
    var body: some View {
        HStack {
            // Use FamilyControls Label - the official App Store compliant way
            // This automatically displays the real app icon and name
            Label(applicationToken)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Time picker
            Menu {
                ForEach(timeLimitOptions, id: \.self) { minutes in
                    Button(formatTime(minutes)) {
                        timeLimit = minutes
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(formatTime(timeLimit))
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}

// MARK: - ⚠️ LEGACY / DEFUNCT (Do Not Use)
// ============================================================================
//  This view is NOT used by the live onboarding flow.
//  It remains only as a reference while AnimatedLimitsIntroView is active.
//  Do NOT import or embed this view in new code. Prefer AnimatedLimitsIntroView.
//  Consider deleting this entire struct before release.
// ============================================================================
#if DEBUG
#warning("OnboardingAppSelectionLegacy is DEFUNCT. Prefer AnimatedLimitsIntroView. Remove before release if unreferenced.")
#endif
@available(*, deprecated, message: "DEFUNCT: Use AnimatedLimitsIntroView instead. This view is not part of the live flow.")
struct OnboardingAppSelectionLegacy: View {
    let page: OnboardingPage
    @Binding var localSelection: FamilyActivitySelection
    let onContinue: () -> Void
    
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingAppPicker = false
    @State private var appTimeLimits: [String: Int] = [:]
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
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
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text(page.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
                
                // Selection status
                selectionStatusView
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(1.0), value: textOpacity)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Selected apps with time limits using real FamilyControls Labels
            if !localSelection.applicationTokens.isEmpty {
                // (Inline Add App chip removed; bottom overlay button matches Setup styling)

                ZStack {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Array(localSelection.applicationTokens.enumerated()), id: \.offset) { index, token in
                                RealAppLimitCard(
                                    applicationToken: token,
                                    timeLimit: Binding(
                                        get: { appTimeLimits[token.identifier] ?? 20 },
                                        set: { appTimeLimits[token.identifier] = $0 }
                                    )
                                )
                            }
                            // Extra dead-space to avoid overlap with bottom overlay button
                            Color.clear.frame(height: 140)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    .frame(maxHeight: 320)
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
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
            
            Spacer()
            
            // Action buttons - Fixed positioning
            VStack(spacing: DesignSystem.Spacing.md) {
                Button(action: { showingAppPicker = true }) {
                    HStack {
                        if !localSelection.applicationTokens.isEmpty {
                            Image(systemName: "plus.circle.fill")
                            Text("Add App").fontWeight(.semibold)
                        } else {
                            Text("Select Apps to Limit").fontWeight(.semibold)
                        }
                    }
                }
                .mindLockButton(style: .primary)
                
                if !localSelection.applicationTokens.isEmpty {
                    Button("Continue") {
                        // Use the same logic as setup screen but without immediate blocking
                        saveAppLimits(applyBlockingImmediately: false)
                        onContinue()
                    }
                    .mindLockButton(style: .secondary)
                } else {
                    Button("Skip for Now") {
                        onContinue()
                    }
                    .mindLockButton(style: .secondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .onAppear {
            // Initialize local selection with current manager state
            localSelection = screenTimeManager.selectedApps
            loadAppTimeLimits()
            
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
        }
        .familyActivityPicker(
            isPresented: $showingAppPicker,
            selection: $localSelection
        )
        .onChange(of: localSelection.applicationTokens) { oldValue, newValue in
            initializeTimeLimitsForNewApps()
        }
    }
    
    @ViewBuilder
    private var selectionStatusView: some View {
        let totalSelected = localSelection.applicationTokens.count
        
        if totalSelected > 0 {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.success)
                
                Text("\(totalSelected) app\(totalSelected == 1 ? "" : "s") selected")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.success)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.success.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.sm)
        } else {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Text("No apps selected")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surfaceSecondary)
            .cornerRadius(DesignSystem.CornerRadius.sm)
        }
    }
    
    private func saveAppLimits(applyBlockingImmediately: Bool = false) {
        // Update the main screen time manager
        screenTimeManager.updateSelectedApps(localSelection)
        
        // Save app selection
        do {
            let data = try JSONEncoder().encode(localSelection)
            UserDefaults.standard.set(data, forKey: "selectedApps")
        } catch {
            print("❌ Failed to save selected apps: \(error)")
        }
        
        // Save time limits
        UserDefaults.standard.set(appTimeLimits, forKey: "appTimeLimits")
        print("💾 Saved app limits: \(appTimeLimits)")

        // Set up proper time-based monitoring instead of immediate blocking
        let limitsManager = DailyLimitsManager.shared
        
        // Set limits for each app in the DailyLimitsManager (immediate)
        for (identifier, minutes) in appTimeLimits {
            // Convert minutes to seconds
            let limitInSeconds = TimeInterval(minutes * 60)
            
            // Find the corresponding ApplicationToken
            if let token = localSelection.applicationTokens.first(where: { $0.identifier == identifier }) {
                limitsManager.setLimitImmediate(for: token, limit: limitInSeconds)
                print("📝 Onboarding set limit for app: \(minutes) minutes (active now)")
            }
        }
        
        print("📝 Limits saved - apps will block after their time limits are reached")
    }
    
    private func loadAppTimeLimits() {
        if let saved = UserDefaults.standard.object(forKey: "appTimeLimits") as? [String: Int] {
            var migrated: [String: Int] = [:]
            for (key, value) in saved {
                if Data(base64Encoded: key) != nil {
                    migrated[key] = value
                }
            }
            appTimeLimits = migrated
        }
    }
    
    private func initializeTimeLimitsForNewApps() {
        // Initialize time limits for new app tokens
        for token in localSelection.applicationTokens {
            let key = token.identifier
            if appTimeLimits[key] == nil {
                appTimeLimits[key] = 20 // Default 20 minutes
            }
        }
    }
}

// MARK: - Pricing Tier Data Model
struct PricingTier: Identifiable, Equatable, Codable {
    var id = UUID()
    let name: String
    let description: String
    let emoji: String
    let fifteenMinPrice: String
    let thirtyMinPrice: String
    let fullDayPrice: String
    
    static let easy = PricingTier(
        name: "Easy Mode",
        description: "Gentle motivation with lower unlock costs",
        emoji: "😊",
        fifteenMinPrice: "$0.50",
        thirtyMinPrice: "$1.00",
        fullDayPrice: "$2.00"
    )
    
    static let moderate = PricingTier(
        name: "Balanced",
        description: "Moderate pricing for steady progress",
        emoji: "⚖️",
        fifteenMinPrice: "$1.00",
        thirtyMinPrice: "$2.00",
        fullDayPrice: "$3.00"
    )
    
    static let strict = PricingTier(
        name: "Strict Mode",
        description: "Higher costs for serious commitment",
        emoji: "🔒",
        fifteenMinPrice: "$2.00",
        thirtyMinPrice: "$4.00",
        fullDayPrice: "$6.00"
    )
    
    static let allTiers = [easy, moderate, strict]
}

struct CharitySelectionView: View {
    let page: OnboardingPage
    @Binding var selectedCharity: Charity?
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
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
            
            // Charity options
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Charity.popularCharities) { charity in
                    Button(action: {
                        selectedCharity = charity
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onContinue()
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Charity icon
                            Text(charity.emoji)
                                .font(.system(size: 32))
                                .frame(width: 44, height: 44)
                                .background(charity.color.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(charity.name)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text(charity.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if selectedCharity?.id == charity.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .font(.system(size: 20))
                            } else {
                                Circle()
                                    .stroke(DesignSystem.Colors.textTertiary, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            selectedCharity?.id == charity.id 
                                ? DesignSystem.Colors.primary.opacity(0.1)
                                : DesignSystem.Colors.surface
                        )
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(
                                    selectedCharity?.id == charity.id 
                                        ? DesignSystem.Colors.primary 
                                        : Color.clear, 
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(DesignSystem.Animation.gentle, value: selectedCharity?.id)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
        }
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
    private var maximumGoal: Double {
        let cap: Double = 8.5
        // Ensure the slider range has positive width; avoid min == max which can crash Slider.
        let lowerBound = minimumGoal
        let safeLower = lowerBound
        let baseline = max(dailyUsageHours, safeLower + stepAmount)
        let candidate = min(max(baseline, safeLower + stepAmount), cap)
        return max(candidate, safeLower + stepAmount)
    }
    
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

// MARK: - Pricing Tier Selection View
struct PricingTierSelectionView: View {
    let page: OnboardingPage
    @Binding var selectedPricingTier: PricingTier
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    private let tiers = [PricingTier.easy, PricingTier.moderate, PricingTier.strict]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Illustration - Smaller for better layout
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.2),
                                page.accentColor.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
            
            // Content
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(page.title)
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                
                Text(page.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
                
                // Pricing Tier Selection
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(tiers) { tier in
                        PricingTierCard(
                            tier: tier,
                            isSelected: selectedPricingTier.id == tier.id,
                            onTap: {
                                withAnimation(DesignSystem.Animation.gentle) {
                                    selectedPricingTier = tier
                                }
                            }
                        )
                    }
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            
            // Continue button (add extra bottom padding to avoid crowding nav dots)
            VStack(spacing: DesignSystem.Spacing.md) {
                Button("Continue") {
                    onContinue()
                }
                .mindLockButton(style: .primary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
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

// MARK: - Pricing Tier Card
struct PricingTierCard: View {
    let tier: PricingTier
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(tier.name)
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(tier.description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DesignSystem.Colors.primary)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                
                // Pricing details
                HStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("10 minutes")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(tier.fifteenMinPrice)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("30 minutes")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(tier.thirtyMinPrice)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full day")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(tier.fullDayPrice)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(
                                isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.surface,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
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
        }
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

struct ConceptExplanationView: View {
    let page: OnboardingPage
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    @State private var cardsOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            // Content - Clean and punchy like Opal, centered in screen
            VStack(spacing: DesignSystem.Spacing.xxl) {
                Text(page.title)
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.success],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.4), value: textOpacity)
                
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    Text("Every time you lose control, you create change.")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .opacity(textOpacity)
                        .animation(DesignSystem.Animation.gentle.delay(0.6), value: textOpacity)
                    
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Text("A small fee to scroll again.")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineSpacing(6)
                        
                        Text("A cause of your choice gets funded.")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.success, DesignSystem.Colors.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .fontWeight(.semibold)
                            .lineSpacing(6)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .animation(DesignSystem.Animation.gentle.delay(0.8), value: textOpacity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            
            // Icon at bottom - Giving hands with sparkles
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignSystem.Colors.success.opacity(0.3),
                                DesignSystem.Colors.success.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.success, DesignSystem.Colors.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
                    .animation(DesignSystem.Animation.spring, value: iconScale)
            }
            .opacity(textOpacity)
            .animation(DesignSystem.Animation.gentle.delay(1.0), value: textOpacity)
            .padding(.bottom, DesignSystem.Spacing.xxl)
            
            // Tap hint instead of a button
            Text("Tap to continue")
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.bottom, DesignSystem.Spacing.xxl)
                .opacity(textOpacity)
                .animation(DesignSystem.Animation.gentle.delay(1.2), value: textOpacity)
        }
        // Allow tap anywhere to continue
        .contentShape(Rectangle())
        .onTapGesture {
            onContinue()
        }
        .onAppear {
            withAnimation {
                iconScale = 1.0
                textOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.8
            textOpacity = 0.0
            cardsOpacity = 0.0
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

// MARK: - Animated Limits Intro View
struct AnimatedLimitsIntroView: View {
    let page: OnboardingPage
    let onContinue: () -> Void

    // Sequenced flags so parts accumulate within a block
    @State private var showIntro = true
    @State private var showBlockA = false
    @State private var showA1 = false
    @State private var showA2 = false
    @State private var showA3 = false
    @State private var showBlockB = false
    @State private var showB1 = false
    @State private var showB2 = false
    @State private var showFinal = false
    @State private var showingButton = false

    @State private var showPicker = false
    @State private var localSelection = FamilyActivitySelection()
    @State private var showSelectedList = false
    @State private var appTimeLimits: [String: Int] = [:]
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared

    private let iconSize: CGFloat = 56

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Intro
            if showIntro {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("You pick your limits for each app")
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Block A text parts stacked: A1, IG lock (A2), A3 — appear sequentially and remain
            if showBlockA {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    if showA1 {
                        Text("Once you reach your limit, that app will be locked for the rest of the day.")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    if showA2 {
                        ZStack {
                            loadIcon("instagram")
                                .resizable()
                                .scaledToFit()
                                .frame(width: iconSize, height: iconSize)
                                .grayscale(1.0)
                                .opacity(0.85)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.success)
                                .offset(y: -iconSize * 0.9)
                                .shadow(color: DesignSystem.Colors.success.opacity(0.4), radius: 8)
                        }
                        .padding(.top, DesignSystem.Spacing.xxl)
                        .transition(.opacity.combined(with: .scale))
                    }
                    if showA3 {
                        Text("You can always adjust your limits, but changes will take place the following day.")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
            }

            // Block B stacked parts
            if showBlockB {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    if showB1 {
                        Text("Really feeling the itch on a certain day?")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    if showB2 {
                        Text("Well, you can unlock… For a price...")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
            }

            if showFinal {
                Text("But don’t worry! Part of it goes to a good cause…\nAnd the best part, you get to choose.🕊️")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Spacer()

            // (Top-right Add App chip removed; we will show a bottom overlay button like Setup)

            // Animation area
            ZStack {
                if showIntro {
                    HStack(spacing: DesignSystem.Spacing.xl) {
                        appIconWithLimit(name: "facebook", label: "30m")
                        appIconWithLimit(name: "instagram", label: "20m")
                        appIconWithLimit(name: "tik tok", label: "1h")
                    }
                    .transition(.opacity.combined(with: .scale))
                } else {
                    if showSelectedList {
                        ZStack {
                            ScrollView {
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(Array(localSelection.applicationTokens).sorted { $0.identifier < $1.identifier }, id: \.identifier) { token in
                                        RealAppLimitCard(
                                            applicationToken: token,
                                            timeLimit: Binding(
                                                get: { appTimeLimits[token.identifier] ?? 20 },
                                                set: { appTimeLimits[token.identifier] = $0 }
                                            )
                                        )
                                    }
                                    // dead space so the overlay button never hides the last row
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
                        }
                        .transition(.opacity)
                    } else {
                        EmptyView().transition(.opacity)
                    }
                }
            }
            .frame(height: (showIntro || showSelectedList) ? 320 : 0)

            Spacer()

            if showingButton && !showSelectedList {
                Button("Select apps to limit  +") { showPicker = true }
                .mindLockButton(style: .primary)
                .transition(.opacity)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }

            if showSelectedList {
                // Add App (text-only) above Continue — icon = white filled circle + black plus
                Button(action: { showPicker = true }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                        }
                        Text("Add App").fontWeight(.semibold)
                    }
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .transition(.opacity)

                Button("Continue") {
                    screenTimeManager.updateSelectedApps(localSelection)
                    let limitsManager = DailyLimitsManager.shared
                    for token in localSelection.applicationTokens {
                        let minutes = appTimeLimits[token.identifier] ?? 20
                        limitsManager.setLimitImmediate(for: token, limit: TimeInterval(minutes * 60))
                    }
                    onContinue()
                }
                .mindLockButton(style: .primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .onAppear {
            runSequence()
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $localSelection)
        .onChange(of: localSelection.applicationTokens) { _, newValue in
            if !newValue.isEmpty {
                for t in newValue { if appTimeLimits[t.identifier] == nil { appTimeLimits[t.identifier] = 20 } }
                withAnimation(.easeInOut(duration: 0.4)) { showSelectedList = true }
            }
        }
    }

    private func appIconWithLimit(name: String, label: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .transition(.opacity)
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

    private func runSequence() {
        // Intro visible
        withAnimation(.easeInOut(duration: 0.5)) { showIntro = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.4)) { showIntro = false }
            // Block A starts
            withAnimation(.easeInOut(duration: 0.5)) { showBlockA = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.5)) { showA1 = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeInOut(duration: 0.5)) { showA2 = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.easeInOut(duration: 0.5)) { showA3 = true }
                        // Beat to read
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showBlockA = false; showA1 = false; showA2 = false; showA3 = false
                            }
                            // Block B starts
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.5)) { showBlockB = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.easeInOut(duration: 0.5)) { showB1 = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                        withAnimation(.easeInOut(duration: 0.6)) { showB2 = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                showBlockB = false; showB1 = false; showB2 = false
                                            }
                                            // Final message and CTA
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.easeInOut(duration: 0.5)) { showFinal = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    withAnimation(.easeInOut(duration: 0.6)) { showingButton = true }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Charity Data Model
struct Charity: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let colorName: String // Store color as string for Codable
    
    var color: Color {
        switch colorName {
        case "red": return .red
        case "primary": return DesignSystem.Colors.primary
        case "success": return DesignSystem.Colors.success
        case "warning": return DesignSystem.Colors.warning
        case "accent": return DesignSystem.Colors.accent
        default: return DesignSystem.Colors.primary
        }
    }
    
    static let popularCharities = [
        Charity(
            id: "red-cross",
            name: "American Red Cross",
            description: "Disaster relief and emergency assistance",
            emoji: "🏥",
            colorName: "red"
        ),
        Charity(
            id: "doctors-without-borders",
            name: "Doctors Without Borders",
            description: "Medical aid in conflict zones worldwide",
            emoji: "🩺",
            colorName: "primary"
        ),
        Charity(
            id: "world-wildlife-fund",
            name: "World Wildlife Fund",
            description: "Conservation and environmental protection",
            emoji: "🐼",
            colorName: "success"
        ),
        Charity(
            id: "feeding-america",
            name: "Feeding America",
            description: "Fighting hunger across the United States",
            emoji: "🍎",
            colorName: "warning"
        ),
        Charity(
            id: "unicef",
            name: "UNICEF",
            description: "Children's rights and emergency relief",
            emoji: "👶",
            colorName: "accent"
        )
    ]
}

// MARK: - Data Model
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
    let isCharityPage: Bool
    let isGoalSettingPage: Bool
    let isPricingTierPage: Bool
    let isConceptPage: Bool
    let isAnimatedLimitsIntroPage: Bool
    
    var isInteractivePage: Bool {
        return isPermissionPage || isUsageQuestionPage || isAgeQuestionPage || isImpactPage || isTimeLimitPage || isCharityPage || isGoalSettingPage || isPricingTierPage || isConceptPage || isAnimatedLimitsIntroPage
    }
    
    static let allPages = [
        OnboardingPage(
            title: "Welcome to MindLock",
            description: "Transform your relationship with technology by setting mindful limits and supporting great causes.",
            iconName: "brain.head.profile",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "How much time do you spend on your phone daily?",
            description: "Be honest - this helps us understand your current habits.",
            iconName: "iphone",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: false,
            isUsageQuestionPage: true,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "What's your age range?",
            description: "This helps us calculate your lifetime digital usage.",
            iconName: "person.fill",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: true,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "Your Digital Future",
            description: "Here's what your current usage means for your lifetime.",
            iconName: "exclamationmark.triangle.fill",
            accentColor: DesignSystem.Colors.warning,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: true,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "Enable Screen Time",
            description: "MindLock needs Screen Time access to monitor your app usage and enforce healthy digital boundaries.",
            iconName: "iphone.and.arrow.forward",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: true,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "How Limits Work",
            description: "A quick explainer before you pick apps to limit.",
            iconName: "apps.iphone",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: true
        ),
        // Defunct page removed: app selection happens inline in the animated intro
        OnboardingPage(
            title: "Turn Slips Into Impact",
            description: "Every time you lose control, you create change.\nA small fee to scroll again. A cause gets funded.",
            iconName: "hands.and.sparkles.fill",
            accentColor: DesignSystem.Colors.warning,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: true,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "Choose Your Charity",
            description: "Select an organization to receive a percentage of your unlock fees. Every extra minute supports a good cause.",
            iconName: "heart.fill",
            accentColor: DesignSystem.Colors.success,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: true,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "Set Your Daily Goal",
            description: "Choose a target that keeps you honest. You can always adjust this later.",
            iconName: "target",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: true,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "Choose Your Pricing Tier",
            description: "Select the level of restrictions and unlock fees for your MindLock experience.",
            iconName: "creditcard.fill",
            accentColor: DesignSystem.Colors.primary,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: true,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        ),
        OnboardingPage(
            title: "Stay Mindful",
            description: "Get insights into your usage patterns and make intentional choices about your digital time.",
            iconName: "chart.line.uptrend.xyaxis",
            accentColor: DesignSystem.Colors.accent,
            isPermissionPage: false,
            isUsageQuestionPage: false,
            isAgeQuestionPage: false,
            isImpactPage: false,
            isTimeLimitPage: false,
            isCharityPage: false,
            isGoalSettingPage: false,
            isPricingTierPage: false,
            isConceptPage: false,
            isAnimatedLimitsIntroPage: false
        )
    ]
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
