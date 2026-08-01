import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SetupView()
                .tabItem {
                    Image(systemName: "lock.circle")
                }
                .tag(0)

            JourneyTrackerView()
                .tabItem {
                    Image(systemName: "map.fill")
                }
                .tag(1)

            MindLockUsageReportScreen()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                }
                .tag(3)
        }
        .preferredColorScheme(.dark)
        .accentColor(DesignSystem.Colors.primary)
        // Auto-presenting the paywall on limit events is disabled.
        .onAppear {
            // Customize tab bar appearance for dark theme
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(DesignSystem.Colors.background)
            
            // Normal state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(DesignSystem.Colors.textTertiary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(DesignSystem.Colors.textTertiary)
            ]
            
            // Selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(DesignSystem.Colors.primary)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(DesignSystem.Colors.primary)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
