import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

enum SetupWalkthroughStep: Int {
    case appLimits
    case timeBlocks
}

private struct IdentifiedApplicationToken: Identifiable, Equatable {
    let token: ApplicationToken
    var id: String { SharedSettings.tokenKey(token) }
}

struct SetupView: View {
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var limitsManager = DailyLimitsManager.shared
    @State private var showingAppPicker = false
    @State private var showingAppLimits = false
    @State private var appTimeLimits: [String: Int] = [:]
    @State private var tokenPendingWait: IdentifiedApplicationToken?
    @State private var subscriptionActive = SharedSettings.isSubscriptionActive()
    @State private var preferredUnlockMechanism = SharedSettings.preferredUnlockMechanism()
    @State private var showingMindLockPlusPaywall = false
    @State private var showingUnlockMechanismSettings = false
    @AppStorage("setup.walkthrough.completed") private var setupWalkthroughCompleted = false
    @State private var walkthroughStep: SetupWalkthroughStep?

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.AppBackground()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("MindLock")
                                    .font(DesignSystem.Typography.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)

                            Button {
                                showingUnlockMechanismSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .frame(width: 42, height: 42)
                                    .glossySurface(cornerRadius: 21, opacity: 0.8)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Unlock settings")
                        }
                        .padding(.top, DesignSystem.Spacing.lg)

                        appLimitsSection

                        // Time Blocks Section
                        TimeBlocksView(
                            walkthroughStep: $walkthroughStep,
                            walkthroughComplete: $setupWalkthroughCompleted
                        )
                        .environmentObject(screenTimeManager)
                        .padding(.top, DesignSystem.Spacing.lg)

                        if !reachedLimitTokens.isEmpty {
                            LimitReachedGlobalCard(
                                tokens: reachedLimitTokens,
                                waitAction: { if let token = representativeToken { tokenPendingWait = IdentifiedApplicationToken(token: token) } }
                            )
                        }

                        ExerciseUnlockSection(
                            subscriptionActive: subscriptionActive,
                            preferredUnlockMechanism: preferredUnlockMechanism,
                            onOpenSettings: { showingUnlockMechanismSettings = true },
                            onSubscribe: { showingMindLockPlusPaywall = true }
                        )

#if DEBUG
                        SetupDebugActions(screenTimeManager: screenTimeManager, limitsManager: limitsManager, showPaywall: {
                            showingMindLockPlusPaywall = true
                        })
#endif
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
                .sheet(isPresented: $showingMindLockPlusPaywall) {
                    UnlockPromptView()
                }
                .sheet(isPresented: $showingUnlockMechanismSettings, onDismiss: loadUserPreferences) {
                    UnlockMechanismSettingsView()
                }
                .sheet(item: $tokenPendingWait) { wrapper in
                    WaitUnlockView(appToken: wrapper.token)
                        .environmentObject(limitsManager)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAppLimits) {
            AppLimitsSetupView(isPresented: $showingAppLimits)
        }
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $screenTimeManager.selectedApps)
        .onAppear {
            loadUserPreferences()
            print("🏠 SetupView appeared. ScreenTimeManager selectedApps count: \(screenTimeManager.selectedApps.applicationTokens.count)")
            let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingCompleted")
            if onboardingDone && !setupWalkthroughCompleted && walkthroughStep == nil {
                walkthroughStep = .appLimits
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh data when app comes to foreground
            loadUserPreferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.subscriptionStatusChangedNotification)) { _ in
            subscriptionActive = SharedSettings.isSubscriptionActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.unlockMechanismChangedNotification)) { _ in
            preferredUnlockMechanism = SharedSettings.preferredUnlockMechanism()
        }
    }

    private func loadUserPreferences() {
        subscriptionActive = SharedSettings.isSubscriptionActive()
        preferredUnlockMechanism = SharedSettings.preferredUnlockMechanism()
    }

    // Tokens that have reached today's limit (union of computed + recent blocks)
    private var limitedTokensFromLimits: [ApplicationToken] {
        let currentIDs = Set(limitsManager.currentLimits.appLimits.keys)
        let pendingIDs = Set(limitsManager.pendingLimits.appLimits.keys)
        let allIDs = currentIDs.union(pendingIDs)
        return allIDs.compactMap { ApplicationToken(identifier: $0) }
    }

    private var reachedLimitTokens: [ApplicationToken] {
        // Depend on recentlyBlockedTokens for SwiftUI updates, but read canonical snapshot for accuracy.
        _ = limitsManager.recentlyBlockedTokens
        var tokens = SharedSettings.currentShieldSnapshot().allTokens
        tokens.formUnion(ManagedSettingsStore().shield.applications ?? [])
        return Array(tokens)
    }

    private var representativeToken: ApplicationToken? {
        reachedLimitTokens.first ?? limitedTokensFromLimits.first
    }

    private var appLimitsSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if walkthroughStep == .appLimits {
                SetupTooltip(
                    text: "Set daily minutes per app. When you run out, MindLock locks that app until tomorrow.",
                    actionTitle: "Next",
                    arrow: .down
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        walkthroughStep = .timeBlocks
                    }
                }
            }
            AppLimitsSectionCard(
                limitsManager: limitsManager
            ) {
                showingAppLimits = true
            }
        }
    }

}

// MARK: - App Limits Section Card
struct AppLimitsSectionCard: View {
    let limitsManager: DailyLimitsManager
    let action: () -> Void

    private let maxDisplayedApps = 3

    private var limitedTokens: [ApplicationToken] {
        let currentIDs = Set(limitsManager.currentLimits.appLimits.keys)
        let pendingIDs = Set(limitsManager.pendingLimits.appLimits.keys)
        let allIDs = currentIDs.union(pendingIDs)

        let tokens = allIDs.compactMap { ApplicationToken(identifier: $0) }
        return tokens.sorted { $0.identifier < $1.identifier }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: "apps.iphone")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("App Limits")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if limitedTokens.isEmpty {
                        Text("Not configured")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(Array(limitedTokens.prefix(maxDisplayedApps).enumerated()), id: \.offset) { _, token in
                                Label(token)
                                    .labelStyle(.iconOnly)
                                    .frame(width: 20, height: 20)
                            }

                            if limitedTokens.count > maxDisplayedApps {
                                Text("+\(limitedTokens.count - maxDisplayedApps)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.lg)
            .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}


#if DEBUG
private struct SetupDebugActions: View {
    @ObservedObject var screenTimeManager: ScreenTimeManager
    @ObservedObject var limitsManager: DailyLimitsManager
    let showPaywall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Divider()
            Text("Developer Tools")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Button {
                limitsManager.debugForceBlockSelectedApps()
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Force Block Selected Apps")
                    Spacer()
                }
                .padding()
                .glossySurface(base: DesignSystem.Colors.surfaceSecondary, cornerRadius: DesignSystem.CornerRadius.md)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .buttonStyle(.plain)

            Button(action: showPaywall) {
                HStack {
                    Image(systemName: "creditcard")
                    Text("Show MindLock+ Paywall")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .glossySurface(base: DesignSystem.Colors.surfaceSecondary, cornerRadius: DesignSystem.CornerRadius.md)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .buttonStyle(.plain)

            Button {
                screenTimeManager.startReviewerBlock()
            } label: {
                HStack {
                    Image(systemName: "eye")
                    Text("Start 2-min Reviewer Block")
                    Spacer()
                }
                .padding()
                .glossySurface(base: DesignSystem.Colors.surfaceSecondary, cornerRadius: DesignSystem.CornerRadius.md)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 0.5)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}
#endif

// MARK: - Limit Reached Global Card
private struct LimitReachedGlobalCard: View {
    let tokens: [ApplicationToken]
    let waitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(limitTitle)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(detailLine)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(previewTokens, id: \.identifier) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.Colors.primary.opacity(0.08))
                        .cornerRadius(12)
                }
                if tokens.count > previewTokens.count {
                    Text("+\(tokens.count - previewTokens.count)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .fontWeight(.semibold)
                }
            }

            Button(action: waitAction) {
                Label {
                    Text("Unlock more time")
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .mindLockButton(style: .primary)
        }
        .padding(DesignSystem.Spacing.lg)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl, opacity: 0.5)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var previewTokens: [ApplicationToken] {
        Array(tokens.prefix(3))
    }

    private var limitTitle: String {
        let count = tokens.count
        if count == 1 { return "1 app locked" }
        return "\(count) apps locked"
    }

    private var detailLine: String {
        let count = tokens.count
        if count == 1 {
            return "1 app is currently locked."
        } else {
            return "\(count) apps are currently locked."
        }
    }
}

private struct UnlockMechanismSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection = SharedSettings.preferredUnlockMechanism()

    private let options: [(SharedSettings.UnlockMechanism, String, String)] = [
        (.mindfulWait, "clock.arrow.circlepath", "Mindful wait"),
        (.pushups, "figure.strengthtraining.traditional", "5 pushups"),
        (.squats, "figure.strengthtraining.traditional", "10 squats")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Choose your unlock method")
                        .font(DesignSystem.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(options, id: \.0.rawValue) { option in
                        Button {
                            selection = option.0
                            SharedSettings.setPreferredUnlockMechanism(option.0)
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: option.1)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(selection == option.0 ? .white : DesignSystem.Colors.primary)
                                    .frame(width: 42, height: 42)
                                    .background(selection == option.0 ? DesignSystem.Colors.primary : DesignSystem.Colors.primary.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.2)
                                        .font(DesignSystem.Typography.body.weight(.semibold))
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                }

                                Spacer()

                                Image(systemName: selection == option.0 ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selection == option.0 ? DesignSystem.Colors.primary : DesignSystem.Colors.textTertiary)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(selection == option.0 ? DesignSystem.Colors.primary.opacity(0.12) : DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.lg)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button("Done") { dismiss() }
                    .mindLockButton(style: .primary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
            .background(DesignSystem.AppBackground())
            .navigationBarHidden(true)
        }
    }
}

private struct ExerciseUnlockSection: View {
    let subscriptionActive: Bool
    let preferredUnlockMechanism: SharedSettings.UnlockMechanism
    let onOpenSettings: () -> Void
    let onSubscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Unlock method")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .glossySurface(cornerRadius: 18, opacity: 0.8)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Unlock method settings")
            }

            currentMethodCard

            if !subscriptionActive {
                Button(action: onSubscribe) {
                    Label {
                        Text("Join MindLock+")
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .frame(maxWidth: .infinity)
                }
                .mindLockButton(style: .impact)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl, opacity: 0.5)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var currentMethodCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 46, height: 46)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))

            VStack(alignment: .leading, spacing: 4) {
                Text(preferredUnlockMechanism.displayName)
                    .font(DesignSystem.Typography.body.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 0.6)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private var iconName: String {
        switch preferredUnlockMechanism {
        case .mindfulWait:
            return "clock.arrow.circlepath"
        case .pushups, .squats:
            return "figure.strengthtraining.traditional"
        }
    }

}

// Testing components removed from production build

// MARK: - App Limits Setup View
struct AppLimitsSetupView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var limitsManager = DailyLimitsManager.shared
    @State private var localSelection = FamilyActivitySelection()
    @State private var showingAppPicker = false
    @State private var appTimeLimits: [String: Int] = [:]
    @State private var showDeferralAlert = false
    @State private var hasDeferredChanges = false
    @State private var showingInstantChangePaywall = false
    private enum DeferredLimitOp: Equatable {
        case increase(minutes: Int)
        case removal
    }

    @State private var pendingImmediateOps: [ApplicationToken: Int] = [:] // minutes
    @State private var pendingDeferredOps: [ApplicationToken: DeferredLimitOp] = [:]
    @State private var originalSelection = FamilyActivitySelection()
    @State private var originalTimeLimits: [String: Int] = [:]
    @State private var showDiscardChangesAlert = false
    // Collapsible Pending Changes
    @State private var pendingExpanded: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                listSection
                actionButtonsSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        if hasUnsavedChanges {
                            showDiscardChangesAlert = true
                        } else {
                            isPresented = false
                        }
                    }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        // (No sticky bar — handled by Pending Changes header "Apply All Now")
        .onAppear {
            loadAppLimits()
        }
        .onDisappear {
            // Ensure changes are saved when view disappears
            // No-op: saving handled via explicit Save and policy
        }
        .familyActivityPicker(
            isPresented: $showingAppPicker,
            selection: $localSelection
        )
        .onChange(of: localSelection.applicationTokens) { oldValue, newValue in
            initializeTimeLimitsForNewApps()
        }
        .alert("Changes queued for tomorrow", isPresented: $showDeferralAlert) {
            Button("Apply now", role: .destructive) { showingInstantChangePaywall = true }
            Button("Close", role: .cancel) { }
        } message: {
            Text("To keep you on track, we defer some limit changes until midnight. You can apply them immediately if you prefer.")
        }
        .sheet(isPresented: $showingInstantChangePaywall) {
            InstantChangePaywallView(isPresented: $showingInstantChangePaywall) {
                applyDeferredImmediately()
            }
        }
        .alert("Discard unsaved changes?", isPresented: $showDiscardChangesAlert) {
            Button("Discard", role: .destructive) { isPresented = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved edits. If you close now, your changes will be lost.")
        }
    }

    // MARK: Sections
    @ViewBuilder private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("App Limits")
                .font(DesignSystem.Typography.title1)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Manage your daily time limits for distracting apps")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
    }

    @ViewBuilder private var listSection: some View {
        if !localSelection.applicationTokens.isEmpty {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        let tokens = Array(localSelection.applicationTokens).sorted { $0.identifier < $1.identifier }
                        ForEach(tokens, id: \.identifier) { token in
                            AppLimitRow(
                                token: token,
                                appTimeLimits: $appTimeLimits,
                                reached: limitsManager.hasExceededLimit(for: token)
                            )
                        }
                        if !persistedPendingItems.isEmpty { pendingChangesSection }
                        // Extra scrollable space so overlay button doesn't cover the final rows
                        Color.clear.frame(height: 140)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                }
                Button(action: { showingAppPicker = true }) {
                    HStack { Image(systemName: "plus.circle.fill"); Text("Add App").fontWeight(.semibold) }
                }
                .mindLockButton(style: .secondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        } else {
            Spacer()
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Text("No apps selected")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("Add apps to start managing your screen time")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)

                Button(action: { showingAppPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add App").fontWeight(.semibold)
                    }
                }
                .mindLockButton(style: .primary)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            Spacer()
        }
    }

    @ViewBuilder private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if hasUnsavedChanges {
                Button("Save Changes") {
                    saveAppLimitsWithPolicy()
                    if !hasDeferredChanges { isPresented = false }
                }
                .mindLockButton(style: .primary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }

    // Removed top selected count banner per updated UX

    // MARK: - Pending Changes Section
    @ViewBuilder
    private var pendingChangesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { withAnimation(.easeInOut) { pendingExpanded.toggle() } }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: pendingExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Pending Changes")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
                // Summary chip
                if !persistedPendingItems.isEmpty {
                    Text("\(persistedPendingItems.count) change\(persistedPendingItems.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glossySurface(base: DesignSystem.Colors.surfaceSecondary)
                        .cornerRadius(10)
                }
                if persistedPendingItems.count > 0 {
                    Button(action: {
                        // Apply all deferred changes via paywall
                        showingInstantChangePaywall = true
                    }) {
                        Text("Apply Now")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            if pendingExpanded {
                // Subtitle explaining midnight application
                Text("Changes will take place at midnight.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.bottom, DesignSystem.Spacing.xs)

                // Each pending item
                ForEach(Array(persistedPendingItems.enumerated()), id: \.offset) { _, entry in
                    let token = entry.0
                    let change = entry.1
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // App icon and name
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Pending target shown like the main list label with a moon glyph
                        switch change {
                        case .increase(let minutes):
                            PendingLimitPill(text: formatMinutesLabel(minutes))
                        case .removal:
                            PendingLimitPill(text: "Remove")
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .glossySurface(base: DesignSystem.Colors.surfaceSecondary, cornerRadius: DesignSystem.CornerRadius.md)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    private func formatMinutesLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 { return "\(hours)h" }
        return "\(hours)h \(rem)m"
    }

    private func loadAppLimits() {
        let currentIDs = Set(limitsManager.currentLimits.appLimits.keys)
        let pendingIDs = Set(limitsManager.pendingLimits.appLimits.keys)
        let allIDs = currentIDs.union(pendingIDs)

        var selection = FamilyActivitySelection()
        var tokens: Set<ApplicationToken> = []
        var uiLimits: [String: Int] = [:]

        for id in allIDs {
            guard let token = ApplicationToken(identifier: id) else { continue }
            tokens.insert(token)
            if let seconds = limitsManager.getCurrentLimit(for: token) {
                uiLimits[id] = max(1, Int(seconds) / 60)
            } else if let pendingSeconds = limitsManager.getPendingLimit(for: token) {
                uiLimits[id] = max(1, Int(pendingSeconds) / 60)
            } else {
                uiLimits[id] = 20
            }
        }

        selection.applicationTokens = tokens
        localSelection = selection
        appTimeLimits = uiLimits
        originalSelection = localSelection
        originalTimeLimits = appTimeLimits
    }

    private func saveAppLimitsWithPolicy() {
        pendingImmediateOps.removeAll(); pendingDeferredOps.removeAll()
        let currentTokens = Set(originalSelection.applicationTokens.map { $0.identifier })
        let newTokens = Set(localSelection.applicationTokens.map { $0.identifier })
        let additions = newTokens.subtracting(currentTokens)
        let removals = currentTokens.subtracting(newTokens)
        let lm = limitsManager

        // Handle additions (immediate)
        for id in additions {
            if let token = localSelection.applicationTokens.first(where: { $0.identifier == id }) {
                let minutes = appTimeLimits[id] ?? 20
                pendingImmediateOps[token] = minutes
            }
        }

        // Handle limit updates
        for id in newTokens.intersection(currentTokens) {
            guard let token = localSelection.applicationTokens.first(where: { $0.identifier == id }) else { continue }
            let newMinutes = appTimeLimits[id] ?? 20
            let currentSeconds = lm.currentLimits.appLimits[id] ?? lm.pendingLimits.appLimits[id] ?? 0
            let currentMinutes = Int(currentSeconds / 60)
            if newMinutes < currentMinutes {
                pendingImmediateOps[token] = newMinutes
            } else if newMinutes > currentMinutes {
                pendingDeferredOps[token] = .increase(minutes: newMinutes)
            }
        }

        // Handle removals (defer)
        for id in removals {
            if let token = screenTimeManager.selectedApps.applicationTokens.first(where: { $0.identifier == id }) {
                pendingDeferredOps[token] = .removal
            }
        }

        // Apply immediate ops
        if !pendingImmediateOps.isEmpty {
            // Update selection immediately for additions
            var updated = screenTimeManager.selectedApps
            for (token, minutes) in pendingImmediateOps {
                updated.applicationTokens.insert(token)
                lm.setLimit(for: token, limit: TimeInterval(minutes * 60))
                // Keep UI state in sync
                appTimeLimits[token.identifier] = minutes
            }
            screenTimeManager.updateSelectedApps(updated)
        }

        // Apply deferred ops to pending only
        hasDeferredChanges = !pendingDeferredOps.isEmpty
            if hasDeferredChanges {
                for (token, op) in pendingDeferredOps {
                switch op {
                case .increase(let minutes):
                    lm.setPendingLimitOnly(for: token, limit: TimeInterval(minutes * 60))
                case .removal:
                    lm.deferRemoval(for: token)
                }
            }
            showDeferralAlert = true
            // Best-effort midnight reminder
            NotificationManager.shared.scheduleSettingsUpdatedAtMidnightIfNeeded()

            // Reset UI to reflect today's active limits and selection
            // Revert local list to current selection for today
            localSelection = screenTimeManager.selectedApps
            // For increased limits that were deferred, show today's value again
            for (token, op) in pendingDeferredOps {
                guard case .increase = op else { continue }
                let id = token.identifier
                if let currentSec = lm.currentLimits.appLimits[id] {
                    appTimeLimits[id] = max(1, Int(currentSec) / 60)
                }
            }
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

    private func applyDeferredImmediately() {
        let lm = limitsManager
        let items: [(ApplicationToken, DeferredLimitOp)]

        if !persistedPendingItems.isEmpty {
            items = persistedPendingItems
        } else {
            items = pendingDeferredOps.map { ($0.key, $0.value) }
        }

        guard !items.isEmpty else { return }

        // Apply deferred ops to current immediately
        for (token, op) in items {
            // Use the token instance from current selection when mutating selection to avoid identity issues
            let selToken = screenTimeManager.selectedApps.applicationTokens.first(where: { $0.identifier == token.identifier }) ?? token
            switch op {
            case .increase(let minutes):
                lm.setLimit(for: selToken, limit: TimeInterval(minutes * 60))
                appTimeLimits[selToken.identifier] = minutes
            case .removal:
                var updated = screenTimeManager.selectedApps
                updated.applicationTokens.remove(selToken)
                screenTimeManager.updateSelectedApps(updated)
                lm.removeLimitImmediate(for: selToken)
                appTimeLimits.removeValue(forKey: selToken.identifier)
            }
        }

        localSelection = screenTimeManager.selectedApps
        originalSelection = localSelection
        originalTimeLimits = appTimeLimits

        pendingDeferredOps.removeAll()
        // Ensure final schedule reflects the batch
        ScreenTimeManager.shared.refreshMonitoringSchedule(reason: "apply now batch")

        hasDeferredChanges = !persistedPendingItems.isEmpty
        // Success toast/alert + notification
        let alert = UIAlertController(title: "Changes Applied", message: "Your new limits are live. Thanks for backing your focus.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        UIApplication.shared.topMostViewController()?.present(alert, animated: true)
        NotificationManager.shared.postSettingsUpdatedNotification()
    }

    // Build persisted pending items from DailyLimitsManager so the section survives screen closure and sessions
    private var persistedPendingItems: [(ApplicationToken, DeferredLimitOp)] {
        let lm = limitsManager
        let current = lm.currentLimits.appLimits
        let pending = lm.pendingLimits.appLimits
        let ids = Set(current.keys).union(pending.keys)
        var pendingItems: [(ApplicationToken, DeferredLimitOp)] = []

        for id in ids {
            guard let token = ApplicationToken(identifier: id) else { continue }
            let currentValue = current[id]
            let pendingValue = pending[id]

            if let currentValue = currentValue, let pendingValue = pendingValue, pendingValue > currentValue {
                let minutes = max(1, Int((pendingValue / 60).rounded()))
                pendingItems.append((token, .increase(minutes: minutes)))
            } else if currentValue != nil && pendingValue == nil {
                pendingItems.append((token, .removal))
            }
        }

        return pendingItems.sorted { $0.0.identifier < $1.0.identifier }
    }

    // MARK: - Dirty check
    private var hasUnsavedChanges: Bool {
        let originalIDs = Set(originalSelection.applicationTokens.map { $0.identifier })
        let currentIDs = Set(localSelection.applicationTokens.map { $0.identifier })
        if originalIDs != currentIDs { return true }
        let unionIDs = originalIDs.union(currentIDs)
        for id in unionIDs {
            if originalTimeLimits[id] != appTimeLimits[id] { return true }
        }
        return false
    }
}

// MARK: - App Limit Card
struct AppLimitCard: View {
    let applicationToken: ApplicationToken
    @Binding var timeLimit: Int
    let reachedLimit: Bool

    private let timeLimitOptions = [10, 15, 20, 30, 45, 60, 90, 120, 180, 240] // Minutes

    var body: some View {
        HStack {
            // Use FamilyControls Label - the official App Store compliant way
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
                        .foregroundColor(reachedLimit ? DesignSystem.Colors.accent : DesignSystem.Colors.primary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(reachedLimit ? DesignSystem.Colors.accent : DesignSystem.Colors.primary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background((reachedLimit ? DesignSystem.Colors.accent : DesignSystem.Colors.primary).opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }

        }
        .padding(DesignSystem.Spacing.md)
        .background(reachedLimit ? DesignSystem.Colors.accent.opacity(0.06) : DesignSystem.Colors.surface)
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

// Break out row to help the compiler and improve readability
private struct AppLimitRow: View {
    let token: ApplicationToken
    @Binding var appTimeLimits: [String: Int]
    let reached: Bool

    private var timeLimitBinding: Binding<Int> {
        Binding(
            get: { appTimeLimits[token.identifier] ?? 20 },
            set: { appTimeLimits[token.identifier] = $0 }
        )
    }

    var body: some View {
        AppLimitCard(
            applicationToken: token,
            timeLimit: timeLimitBinding,
            reachedLimit: reached
        )
    }
}

// Small pill used in Pending Changes to mirror the time label style with a moon glyph
private struct PendingLimitPill: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
            Image(systemName: "moon.fill")
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.primary.opacity(0.1))
        .foregroundColor(DesignSystem.Colors.primary)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Instant Change Confirmation
private struct InstantChangePaywallView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    @State private var remaining = 30
    @State private var timer: Timer?
    @State private var readyToConfirm = false
    private let logoSize: CGFloat = 120
    private var progress: Double { Double(30 - remaining) / 30 }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Mindful change")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.top, DesignSystem.Spacing.xl)

            VStack(spacing: DesignSystem.Spacing.md) {
                logoProgressView
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(readyToConfirm ? "Ready when you are" : "Take a breath")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(readyToConfirm ? "✓" : "\(remaining)s")
                        .font(.system(size: readyToConfirm ? 42 : 48, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl)
            .cornerRadius(DesignSystem.CornerRadius.xl)
            .padding(.horizontal, DesignSystem.Spacing.lg)

            VStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Text("Apply limit changes immediately")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("Use this 30-second pause to make sure you truly want to loosen today’s limits. When you’re ready, we’ll apply all pending changes at once.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Button("Apply pending limits now") {
                    guard readyToConfirm else { return }
                    onConfirm()
                    dismiss()
                }
                .mindLockButton(style: .primary)
                .disabled(!readyToConfirm)
                .opacity(readyToConfirm ? 1 : 0.5)

                Button("Keep limits as-is") {
                    dismiss()
                }
                .mindLockButton(style: .ghost)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.AppBackground())
        .onAppear(perform: beginCountdown)
        .onDisappear(perform: invalidate)
    }

    private func beginCountdown() {
        remaining = 30
        readyToConfirm = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if remaining <= 1 {
                timer.invalidate()
                remaining = 0
                readyToConfirm = true
            } else {
                remaining -= 1
            }
        }
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    private func dismiss() {
        isPresented = false
    }

    private var logoProgressView: some View {
        let clamped = min(max(progress, 0), 1)
        return ZStack {
            Circle()
                .fill(DesignSystem.Colors.background.opacity(0.4))
                .frame(width: logoSize + 24, height: logoSize + 24)
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.surface.opacity(0.6), lineWidth: 2)
                )
            resolvedLogoImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)
                .clipShape(Circle())
                .opacity(0.25)
            resolvedLogoImage
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
    }

    private var resolvedLogoImage: Image {
        if let uiImage = UIImage(named: "MindLockLogo") {
            return Image(uiImage: uiImage).renderingMode(.original)
        }
        return Image(systemName: "lock.shield.fill")
    }
}

#Preview {
    SetupView()
}
