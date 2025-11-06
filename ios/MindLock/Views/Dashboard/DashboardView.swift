import SwiftUI

struct DashboardView: View {
    @State private var dailyUsage: TimeInterval = 3600 // 1 hour in seconds
    @State private var dailyLimit: TimeInterval = 7200 // 2 hours in seconds
    @State private var isAnimating = false
    @State private var showingAppSelection = false
    
    private var usageProgress: Double {
        min(dailyUsage / dailyLimit, 1.0)
    }
    
    private var remainingTime: TimeInterval {
        max(dailyLimit - dailyUsage, 0)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Usage Overview Card
                    usageOverviewCard
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Apps Grid
                    appsGridSection
                    
                    // Insights Section
                    insightsSection
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionView()
        }
        .onAppear {
            startUsageAnimation()
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Good morning")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text("Stay mindful today")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            Spacer()
            
            // Profile button
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryGradient)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    private var usageOverviewCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        DesignSystem.Colors.surfaceSecondary,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: isAnimating ? usageProgress : 0)
                    .stroke(
                        usageProgress > 0.8 ? 
                        DesignSystem.Colors.accentGradient : 
                        DesignSystem.Colors.primaryGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.gentle, value: isAnimating)
                
                // Center content
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(formatTime(remainingTime))
                        .font(DesignSystem.Typography.title1)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.bold)
                    
                    Text("remaining")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            // Usage stats
            HStack(spacing: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(formatTime(dailyUsage))
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Used Today")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(formatTime(dailyLimit))
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Daily Limit")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .mindLockCard()
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Quick Actions")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                QuickActionButton(
                    title: "Take Break",
                    icon: "pause.circle",
                    color: DesignSystem.Colors.success
                ) {
                    // Handle take break action
                }
                
                QuickActionButton(
                    title: "Setup Apps",
                    icon: "apps.iphone",
                    color: DesignSystem.Colors.primary
                ) {
                    showingAppSelection = true
                }
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gearshape",
                    color: DesignSystem.Colors.textSecondary
                ) {
                    // Handle settings action
                }
            }
        }
    }
    
    private var appsGridSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Your Apps")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button("Manage") {
                    showingAppSelection = true
                }
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DesignSystem.Spacing.md) {
                ForEach(mockApps, id: \.name) { app in
                    AppUsageCard(app: app)
                }
            }
        }
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("This Week")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                InsightCard(
                    title: "Average Daily Use",
                    value: "1h 23m",
                    change: "-12m",
                    isPositive: true
                )
                
                InsightCard(
                    title: "Charity Contributed",
                    value: "$2.40",
                    change: "+$0.80",
                    isPositive: true
                )
            }
        }
    }
    
    private func startUsageAnimation() {
        withAnimation(DesignSystem.Animation.gentle.delay(0.5)) {
            isAnimating = true
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AppUsageCard: View {
    let app: MockApp
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(app.color.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: app.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(app.color)
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(app.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(app.usage)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(value)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: isPositive ? "arrow.down" : "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isPositive ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                
                Text(change)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(isPositive ? DesignSystem.Colors.success : DesignSystem.Colors.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .mindLockCard()
    }
}

// MARK: - Mock Data
struct MockApp {
    let name: String
    let icon: String
    let usage: String
    let color: Color
}

private let mockApps = [
    MockApp(name: "Instagram", icon: "photo", usage: "45m", color: DesignSystem.Colors.accent),
    MockApp(name: "TikTok", icon: "music.note", usage: "32m", color: DesignSystem.Colors.textPrimary),
    MockApp(name: "Twitter", icon: "message", usage: "28m", color: DesignSystem.Colors.primary),
    MockApp(name: "YouTube", icon: "play.rectangle", usage: "1h 12m", color: DesignSystem.Colors.error),
]

#Preview {
    DashboardView()
} 