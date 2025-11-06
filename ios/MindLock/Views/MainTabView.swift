import SwiftUI
import FamilyControls
import ManagedSettings

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var limitsManager: DailyLimitsManager
    @State private var activeBlockedApp: BlockedApp?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Setup Section
            SetupView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Setup")
                }
                .tag(0)
            
            // Analytics Section
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Analytics")
                }
                .tag(1)
            
            // Social Section
            SocialView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Social")
                }
                .tag(2)
            
            // Profile Section
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
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

private struct BlockedApp: Identifiable {
    let token: ApplicationToken
    var id: String { token.identifier }
}
