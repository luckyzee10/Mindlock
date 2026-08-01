import SwiftUI
import FamilyControls
import UIKit

@main
struct MindLockApp: App {
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var limitsManager = DailyLimitsManager.shared
    @StateObject private var paymentManager = PaymentManager()
    @State private var showScreenTimePrompt = false
    @State private var authPromptPrimed = false // avoid early flashes before initial check completes
    @State private var authorizationCheckTask: Task<Void, Never>?
    @State private var isAuthorizationCheckInFlight = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(screenTimeManager)
                .environmentObject(limitsManager)
                .environmentObject(paymentManager)
                .onAppear {
                    AnalyticsService.shared.configure()
                    AnalyticsService.shared.track(.appOpened)
                    AnalyticsService.shared.identifyCurrentUser()
                    NotificationManager.shared.configure()
                    setupNotificationHandling()
                    reevaluateScreenTimePrompt()
                    Task { await paymentManager.refreshSubscriptionStatus() }
                }
                .onOpenURL { _ in
                    // Ensure we present the unlock flow if launched from shield
                    processSharedLimitEvents()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    AnalyticsService.shared.track(.appForegrounded)
                    processSharedLimitEvents()
                    refreshShieldStateFromLedger(reason: "app foregrounded")
                    // Re-check on every foreground entry
                    reevaluateScreenTimePrompt()
                    Task { await paymentManager.refreshSubscriptionStatus() }
                }
                .sheet(isPresented: $showScreenTimePrompt) {
                    ScreenTimeEnablePrompt(onContinue: {
                        Task {
                            do {
                                try await screenTimeManager.requestAuthorization()
                            } catch {
                                print("❌ Screen Time auth failed from prompt: \(error)")
                            }
                            // Reevaluate after attempt
                            reevaluateScreenTimePrompt()
                        }
                    })
                }
                // Keep prompt state in sync with the manager's published status (no re-check loop)
                .onReceive(screenTimeManager.$authorizationStatus) { status in
                    let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingCompleted")
                    // Ignore early transient statuses until the first full check completes
                    guard authPromptPrimed, !isAuthorizationCheckInFlight else { return }
                    showScreenTimePrompt = onboardingDone && (status != .approved)
                }
        }
    }
    
    private func setupNotificationHandling() {
        SharedSettings.observeLimitEvents {
            processSharedLimitEvents()
        }
        
        if let sharedDefaults = SharedSettings.sharedDefaults {
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: sharedDefaults,
                queue: .main
            ) { _ in
                processSharedLimitEvents()
                NotificationCenter.default.post(name: SharedSettings.analyticsUpdatedNotification, object: nil)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppLimitExceeded"),
            object: nil,
            queue: .main
        ) { notification in
            handleAppLimitExceeded(notification)
        }

        processSharedLimitEvents()
    }
    
    private func handleAppLimitExceeded(_ notification: Notification) {
        print("🔔 Received AppLimitExceeded notification from extension")
        
        processSharedLimitEvents()
    }
    
    private func processSharedLimitEvents() {
        guard let event = SharedSettings.pendingLimitEvent() else { return }
        limitsManager.handleLimitEvent(tokens: event.blockedTokens, eventName: event.eventName)
        SharedSettings.clearLimitEvent()
        print("🎯 Ready to present unlock flow for \(event.blockedTokens.count) apps")
    }

    private func refreshShieldStateFromLedger(reason: String) {
        screenTimeManager.enforceActiveTimeBlocksNow()
        limitsManager.refreshBlockingNow()
        SharedSettings.scheduleTemporaryUnlockExpiryMonitoring()
        print("🛡️ Refreshed shield state from ledger: \(reason)")
    }

    private func reevaluateScreenTimePrompt() {
        // Only prompt after onboarding has completed
        let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        guard onboardingDone else {
            authorizationCheckTask?.cancel()
            authorizationCheckTask = nil
            showScreenTimePrompt = false
            authPromptPrimed = false
            isAuthorizationCheckInFlight = false
            return
        }

        // Do a fresh status check first, and only then decide whether to present.
        // This avoids a flash where an old cached value is read on launch.
        showScreenTimePrompt = false
        authPromptPrimed = false
        authorizationCheckTask?.cancel()
        authorizationCheckTask = Task { @MainActor in
            isAuthorizationCheckInFlight = true
            let status = screenTimeManager.refreshAuthorizationStatus()
            guard !Task.isCancelled else {
                isAuthorizationCheckInFlight = false
                authorizationCheckTask = nil
                return
            }

            authPromptPrimed = true
            showScreenTimePrompt = (status != .approved)
            isAuthorizationCheckInFlight = false
            authorizationCheckTask = nil
            print("🔐 Screen Time post-check: status=\(status), showPrompt=\(showScreenTimePrompt)")
        }
    }
}

// MARK: - Screen Time Enable Prompt
private struct ScreenTimeEnablePrompt: View {
    let onContinue: () -> Void
    var body: some View {
        ZStack {
            DesignSystem.AppBackground()
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("Screen Time Access")
                        .font(DesignSystem.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("MindLock uses Screen Time access to monitor usage and enforce the limits you create.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("Continue", action: onContinue)
                    .mindLockButton(style: .primary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}
