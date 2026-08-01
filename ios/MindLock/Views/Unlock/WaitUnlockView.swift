import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

struct WaitUnlockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var limitsManager: DailyLimitsManager
    @Environment(\.scenePhase) private var scenePhase
    let appToken: ApplicationToken

    @State private var remaining = 30
    @State private var timer: Timer?
    @State private var isCompleted = false
    @State private var readyToConfirm = false
    @State private var timeBlockContext: SharedSettings.ActiveTimeBlockState?
    @State private var showingBreakPicker = false
    @State private var showingLanguageChallenge = false
    @State private var subscriptionActive = SharedSettings.isSubscriptionActive()
    @State private var preferredUnlockMechanism = SharedSettings.preferredUnlockMechanism()
    @State private var selectedBreakMinutes: Int = 10
    private let breakOptions: [Int] = Array(1...15) + [24 * 60]
    
    private let logoSize: CGFloat = 140

    private var progress: Double { Double(30 - remaining) / 30 }

    var body: some View {
        Group {
            switch preferredUnlockMechanism {
            case .mindfulWait:
                mindfulWaitBody
            case .languagePractice:
                if subscriptionActive {
                    challengeDurationBody
                } else {
                    UnlockPromptView()
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.track(.unlockFlowStarted, properties: [
                "unlock_method": .string(preferredUnlockMechanism.rawValue),
                "subscription_active": .bool(subscriptionActive)
            ])
            subscriptionActive = SharedSettings.isSubscriptionActive()
            preferredUnlockMechanism = SharedSettings.preferredUnlockMechanism()
            if preferredUnlockMechanism == .mindfulWait {
                beginCountdown()
                timeBlockContext = SharedSettings.currentTimeBlockContext()
            }
        }
        .onDisappear { invalidate() }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.subscriptionStatusChangedNotification)) { _ in
            subscriptionActive = SharedSettings.isSubscriptionActive()
        }
        .onChange(of: scenePhase) { _, phase in
            guard preferredUnlockMechanism == .mindfulWait else { return }
            phase == .active ? resume() : pause()
        }
        .sheet(isPresented: $showingLanguageChallenge) {
            LanguageChallengeView(unlockMinutes: selectedBreakMinutes) { practiced, correct, minutes in
                completeLanguageChallenge(practiced: practiced, correct: correct, minutes: minutes)
            }
        }
    }

    private var mindfulWaitBody: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                header
                countdownCard
                supportCopy
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button("Unlock more time") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showingBreakPicker.toggle()
                        }
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
            .background(DesignSystem.AppBackground())
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) {
                if showingBreakPicker {
                    breakPickerCard
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showingBreakPicker)
    }

    private var challengeDurationBody: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(preferredUnlockMechanism.displayName)
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(challengeIntroCopy)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                breakLengthPicker

                VStack(spacing: DesignSystem.Spacing.md) {
                    Button {
                        startSelectedChallenge()
                    } label: {
                        Label("Start challenge", systemImage: challengeIconName)
                            .frame(maxWidth: .infinity)
                    }
                    .mindLockButton(style: .primary)

                    Button("Not now") {
                        dismiss()
                    }
                    .mindLockButton(style: .ghost)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.xl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
            .background(DesignSystem.AppBackground())
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Mindful wait")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            if let context = timeBlockContext, context.endsAt > Date().timeIntervalSince1970 {
                Text("You're in your \(context.name) block. Your block ends in \(timeRemainingString(context.endsAt)). Pause for 30 seconds to unlock a mindful break.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Take a 30 second pause to reflect before your break.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var countdownCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            logoProgressView
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(readyToConfirm ? "You're good" : "Hold tight")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(readyToConfirm ? "✓" : "\(remaining)s")
                    .font(.system(size: readyToConfirm ? 40 : 48, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var supportCopy: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("This is your reset cue")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Use this moment to notice the urge, take a breath, and remember why you set these limits.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 0.8)
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
    
    private func startBreak() {
        guard readyToConfirm else { return }
        confirmUnlock(minutes: selectedBreakMinutes)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingBreakPicker = false
        }
    }

    private func confirmUnlock(minutes: Int, dismissAfterGrant: Bool = true) {
        AnalyticsService.shared.track(.unlockMinutesGranted, properties: [
            "minutes": .int(minutes),
            "unlock_method": .string(preferredUnlockMechanism.rawValue)
        ])
        limitsManager.grantFreeUnlock(minutes: minutes)
        NotificationManager.shared.postFreeUnlockNotification(minutes: minutes)
        if dismissAfterGrant {
            dismiss()
        }
    }

    private func completeLanguageChallenge(practiced: Int, correct: Int, minutes: Int) {
        confirmUnlock(minutes: minutes, dismissAfterGrant: false)
        showingLanguageChallenge = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dismiss()
        }
    }

    private func startSelectedChallenge() {
        switch preferredUnlockMechanism {
        case .languagePractice:
            showingLanguageChallenge = true
        case .mindfulWait:
            break
        }
    }

    private var challengeIntroCopy: String {
        switch preferredUnlockMechanism {
        case .languagePractice:
            return "Choose how much time you want to unlock, then complete a 4-question \(SharedSettings.preferredLearningLanguage().displayName) lesson."
        case .mindfulWait:
            return ""
        }
    }

    private var challengeIconName: String {
        switch preferredUnlockMechanism {
        case .languagePractice:
            return "text.book.closed.fill"
        case .mindfulWait:
            return "clock.arrow.circlepath"
        }
    }

    private var appName: String {
        Application(token: appToken).localizedDisplayName ?? "this app"
    }

    private func timeRemainingString(_ endsAt: TimeInterval) -> String {
        let remaining = max(0, endsAt - Date().timeIntervalSince1970)
        let minutes = Int(remaining / 60)
        if minutes >= 120 {
            return String(format: "%.1f h", Double(minutes) / 60.0)
        } else if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 { return "\(hours)h" }
            return "\(hours)h \(mins)m"
        } else {
            return "\(max(1, minutes))m"
        }
    }

    private var breakPickerCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Choose unlock length")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            breakLengthPicker

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Cancel") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingBreakPicker = false
                    }
                }
                .mindLockButton(style: .ghost)

                Button("Unlock time") {
                    startBreak()
                }
                .mindLockButton(style: .primary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl)
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    private var breakLengthPicker: some View {
        Picker("Minutes", selection: $selectedBreakMinutes) {
            ForEach(breakOptions, id: \.self) { minute in
                if minute == 24 * 60 {
                    Text("Full day")
                        .font(DesignSystem.Typography.body)
                } else {
                    Text("\(minute) minute\(minute == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.body)
                }
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipped()
        .labelsHidden()
    }
    
    private var logoProgressView: some View {
        let baseImage = resolvedLogoImage
        let clamped = min(max(progress, 0), 1)
        return ZStack {
            Circle()
                .fill(DesignSystem.Colors.background.opacity(0.4))
                .frame(width: logoSize + 28, height: logoSize + 28)
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.surface.opacity(0.6), lineWidth: 2)
                )
            baseImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)
                .clipShape(Circle())
                .opacity(0.25)
            baseImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)
                .clipShape(Circle())
                .mask(
                    Circle()
                        .trim(from: 0, to: CGFloat(clamped))
                        .stroke(style: StrokeStyle(lineWidth: logoSize, lineCap: .butt))
                        .scaleEffect(x: -1, y: 1, anchor: .center)
                        .rotationEffect(.degrees(-90))
                )
        }
        .frame(width: logoSize + 28, height: logoSize + 28)
    }
    
    private var resolvedLogoImage: Image {
        if let uiImage = UIImage(named: "MindLockLogo") {
            return Image(uiImage: uiImage).renderingMode(.original)
        }
        return Image(systemName: "lock.shield.fill")
    }
}
