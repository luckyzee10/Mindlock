import SwiftUI

struct ContentView: View {
    @State private var showOnboarding: Bool = {
        // Only show onboarding on first launch
        let completed = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        return !completed
    }()
    
    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(onComplete: {
                    // Persist that onboarding finished so we don't show it again
                    UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                    withAnimation(DesignSystem.Animation.gentle) {
                        showOnboarding = false
                    }
                })
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(DesignSystem.Animation.gentle, value: showOnboarding)
    }
}

#Preview {
    ContentView()
} 
