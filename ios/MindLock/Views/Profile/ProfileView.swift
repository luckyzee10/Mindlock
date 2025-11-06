import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Profile")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Goals, achievements, and personal stats")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.lg)
                        
                        // Coming Soon Card
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(DesignSystem.Colors.primary)
                            
                            Text("Coming Soon")
                                .font(DesignSystem.Typography.title1)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("• Goal tracking\n• Streak counters\n• Personal achievements\n• Account settings")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(DesignSystem.Spacing.xl)
                        .background(DesignSystem.Colors.surface)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ProfileView()
} 