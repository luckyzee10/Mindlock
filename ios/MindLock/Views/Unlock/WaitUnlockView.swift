import SwiftUI
import FamilyControls
import ManagedSettings

struct WaitUnlockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var limitsManager: DailyLimitsManager
    @Environment(\.scenePhase) private var scenePhase
    let appToken: ApplicationToken

    @State private var remaining = 30
    @State private var timer: Timer?
    @State private var isCompleted = false
    @State private var readyToConfirm = false

    private var progress: Double { Double(30 - remaining) / 30 }

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                header
                countdownCard
                supportCopy
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button("Unlock 10 minutes") {
                        confirmUnlock()
                    }
                    .mindLockButton(style: .primary)
                    .disabled(!readyToConfirm)
                    .opacity(readyToConfirm ? 1 : 0.5)
                    
                    Button("Not now") {
                        dismiss()
                    }
                    .mindLockButton(style: .ghost)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.xl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear { beginCountdown() }
        .onDisappear { invalidate() }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? resume() : pause()
        }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Mindful wait")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(appName) hit its cap. Pause for 30 seconds and every limited app unlocks for 10 mindful minutes.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var countdownCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.surface.opacity(0.4), lineWidth: 12)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DesignSystem.Colors.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(readyToConfirm ? "You're good" : "Hold tight")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(readyToConfirm ? "✓" : "\(remaining)s")
                        .font(.system(size: readyToConfirm ? 40 : 48, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            Text("Keep the screen on to complete the mindful wait. Once finished, all tracked apps open for 10 minutes.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var supportCopy: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Why we pause")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Each countdown is a reset cue—use the moment to notice the urge, take a breath, and remember why you set these limits across all apps.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(DesignSystem.Colors.surface.opacity(0.8))
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func beginCountdown() {
        remaining = 30
        isCompleted = false
        readyToConfirm = false
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if remaining <= 1 {
                timer.invalidate()
                remaining = 0
                countdownComplete()
            } else {
                remaining -= 1
            }
        }
    }

    private func pause() {
        timer?.invalidate()
        timer = nil
    }

    private func resume() {
        guard !isCompleted, timer == nil else { return }
        scheduleTimer()
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    private func countdownComplete() {
        isCompleted = true
        readyToConfirm = true
    }
    
    private func confirmUnlock() {
        guard readyToConfirm else { return }
        limitsManager.grantFreeUnlock(minutes: 10)
        NotificationManager.shared.postFreeUnlockNotification(minutes: 10)
        dismiss()
    }

    private var appName: String {
        Application(token: appToken).localizedDisplayName ?? "this app"
    }
}
