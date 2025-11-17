import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

private struct IdentifiedApplicationToken: Identifiable, Equatable {
    let token: ApplicationToken
    var id: String { SharedSettings.tokenKey(token) }
}

struct SetupView: View {
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var limitsManager = DailyLimitsManager.shared
    @State private var selectedCharity: Charity?
    @State private var showingAppPicker = false
    @State private var showingAppLimits = false
    @State private var showingCharitySelection = false
    @State private var appTimeLimits: [String: Int] = [:]
    @State private var tokenPendingWait: IdentifiedApplicationToken?
    @State private var subscriptionActive = SharedSettings.isSubscriptionActive()
    @State private var showingMindLockPlusPaywall = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("MindLock")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Fine-tune your limits, charities, and unlock options")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.lg)
                        
                        // App Limits Section
                        AppLimitsSectionCard(
                            selectedApps: screenTimeManager.selectedApps,
                            limitsManager: limitsManager
                        ) {
                            showingAppLimits = true
                        }
                        
                        // Charity Selection Section
                        SetupSectionCard(
                            title: "Your Charity",
                            description: "Choose where your donations go",
                            icon: "heart.fill",
                            status: selectedCharity?.name ?? "Not selected",
                            emoji: selectedCharity?.emoji,
                            logoName: selectedCharity?.logoAssetName
                        ) {
                            showingCharitySelection = true
                        }

                        if !subscriptionActive {
                            MindLockPlusPromoCard(selectedCharity: selectedCharity) {
                                showingMindLockPlusPaywall = true
                            }
                        }

                        // Time Blocks Section
                        TimeBlocksView()
                            .environmentObject(screenTimeManager)
                            .padding(.top, DesignSystem.Spacing.lg)

                        // Streak Card
                        StreakCard(days: currentStreakDays)
                        
                        if !subscriptionActive && !reachedLimitTokens.isEmpty {
                            LimitReachedGlobalCard(
                                tokens: reachedLimitTokens,
                                waitAction: { if let token = representativeToken { tokenPendingWait = IdentifiedApplicationToken(token: token) } },
                                mindLockPlusAction: { showingMindLockPlusPaywall = true }
                            )
                        }
                        
#if DEBUG
                        SetupDebugActions(limitsManager: limitsManager)
#endif
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
                .sheet(isPresented: $showingMindLockPlusPaywall) {
                    UnlockPromptView()
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
        .sheet(isPresented: $showingCharitySelection) {
            SetupCharitySelectionView()
        }
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $screenTimeManager.selectedApps)
        .onAppear {
            loadUserPreferences()
            print("🏠 SetupView appeared. ScreenTimeManager selectedApps count: \(screenTimeManager.selectedApps.applicationTokens.count)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh data when app comes to foreground
            loadUserPreferences()
        }
        .onChange(of: showingCharitySelection) { _, isShowing in
            if !isShowing {
                // Reload charity selection when sheet closes
                loadUserPreferences()
                print("💝 Charity selection sheet closed, reloading preferences")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.subscriptionStatusChangedNotification)) { _ in
            subscriptionActive = SharedSettings.isSubscriptionActive()
        }
    }
    
    private func loadUserPreferences() {
        // Load selected charity – prefer id, fallback to legacy JSON blob
        if let charityId = UserDefaults.standard.string(forKey: "selectedCharityId"),
           let charity = Charity.popularCharities.first(where: { $0.id == charityId }) {
            selectedCharity = charity
        } else if let charityData = UserDefaults.standard.data(forKey: "selectedCharity"),
                  let charity = try? JSONDecoder().decode(Charity.self, from: charityData) {
            selectedCharity = charity
            // Normalize to id storage for future reads
            UserDefaults.standard.set(charity.id, forKey: "selectedCharityId")
        } else {
            selectedCharity = nil
        }
        
        print("📱 Loaded user preferences - Charity: \(selectedCharity?.name ?? "None")")
    }

    // Tokens that have reached today's limit (union of computed + recent blocks)
    private var reachedLimitTokens: [ApplicationToken] {
        let selected = screenTimeManager.selectedApps.applicationTokens
        var set = Set<ApplicationToken>()
        for t in selected { if limitsManager.hasExceededLimit(for: t) { set.insert(t) } }
        for t in limitsManager.recentlyBlockedTokens { if selected.contains(t) { set.insert(t) } }
        return Array(set)
    }

    private var representativeToken: ApplicationToken? {
        reachedLimitTokens.first ?? screenTimeManager.selectedApps.applicationTokens.first
    }

    // Compute the number of consecutive days (starting today) with zero unlocks recorded
    private var currentStreakDays: Int {
        SharedSettings.consecutiveUnlockFreeDays()
    }
    
}

// MARK: - App Limits Section Card
struct AppLimitsSectionCard: View {
    let selectedApps: FamilyActivitySelection
    let limitsManager: DailyLimitsManager
    let action: () -> Void
    
    private let maxDisplayedApps = 3
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("App Limits")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Set daily time limits for your apps")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                                         // App icons or status
                     if selectedApps.applicationTokens.isEmpty {
                         Text("Not configured")
                             .font(DesignSystem.Typography.caption)
                             .foregroundColor(DesignSystem.Colors.primary)
                             .frame(maxWidth: .infinity, alignment: .leading)
                     } else {
                                                HStack(spacing: DesignSystem.Spacing.xs) {
                             // Convert set to sorted array to ensure consistent ordering
                             let sortedTokens = Array(selectedApps.applicationTokens).sorted { $0.identifier < $1.identifier }
                             
                             // Show up to 3 app icons
                             ForEach(Array(sortedTokens.prefix(maxDisplayedApps).enumerated()), id: \.offset) { index, token in
                                 Label(token)
                                     .labelStyle(.iconOnly)
                                     .frame(width: 20, height: 20)
                             }
                             
                             // Show +X if there are more apps
                             if selectedApps.applicationTokens.count > maxDisplayedApps {
                                 Text("+\(selectedApps.applicationTokens.count - maxDisplayedApps)")
                                     .font(DesignSystem.Typography.caption)
                                     .foregroundColor(DesignSystem.Colors.primary)
                                     .fontWeight(.medium)
                             }
                         }
                    }
                }
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}

// MARK: - Streak Card
private struct StreakCard: View {
    let days: Int

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Centered title + subtitle
            VStack(spacing: 4) {
                Text("Streak")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Centered flame between text and progress bar
            Image(systemName: "flame.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(fireColor)
                .shadow(color: fireColor.opacity(0.35), radius: days == 0 ? 0 : 6)

            // Segmented line (not pill), with subtle separators
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let ratio = min(Double(days), 28.0) / 28.0
                    let trackColor = DesignSystem.Colors.textTertiary.opacity(days == 0 ? 0.35 : 0.22)
                    let separatorColor = DesignSystem.Colors.textTertiary.opacity(days == 0 ? 0.35 : 0.25)
                    ZStack(alignment: .leading) {
                        // Base line (always visible, greyed out at 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(trackColor)
                            .frame(height: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(DesignSystem.Colors.textTertiary.opacity(0.12), lineWidth: 1)
                            )

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barGradient)
                            .frame(width: width * ratio, height: 8)

                        // Tick separators (no dots)
                        HStack(spacing: 0) {
                            ForEach(1..<5, id: \.self) { _ in
                                Spacer()
                                Rectangle()
                                    .fill(separatorColor)
                                    .frame(width: 1, height: 8)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(height: 8)

                // Centered numeric label
                Text("\(days) \(days == 1 ? "day" : "days")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("Impact multiplier ×\(SharedSettings.impactMultiplier(forStreak: days))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if days >= 28 {
                    Text("You’ve maxed out this month’s boost.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var subtitle: String {
        if days == 0 { return "Start your streak" }
        return "Keep going to amplify donations"
    }

    private var fireColor: Color {
        switch days {
        case 0:
            return DesignSystem.Colors.textTertiary
        case 1..<7:
            return .yellow
        case 7..<14:
            return .orange
        case 14..<21:
            return Color.orange.opacity(0.9)
        case 21..<28:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        default:
            return .red
        }
    }

    private var barGradient: LinearGradient {
        let start = Color.yellow
        let end = Color.red
        return LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing)
    }
}

#if DEBUG
struct StreakCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                StreakCard(days: 0)
                StreakCard(days: 1)
                StreakCard(days: 2)
                StreakCard(days: 3)
                StreakCard(days: 4)
                StreakCard(days: 5)
                StreakCard(days: 12) // beyond 5, bar stays full, count continues
            }
            .padding()
            .background(DesignSystem.Colors.background)
            .previewDisplayName("Streak Levels 0–5+")
        }
    }
}
#endif

// MARK: - Setup Section Card
struct SetupSectionCard: View {
    let title: String
    let description: String
    let icon: String
    let status: String
    let emoji: String?
    let logoName: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Icon
                if let logoName = logoName, let uiImage = UIImage(named: logoName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                            .frame(width: 50, height: 50)
                        if let emoji = emoji, !emoji.isEmpty {
                            Text(emoji)
                                .font(.system(size: 24))
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(description)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(status)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
private struct SetupDebugActions: View {
    @ObservedObject var limitsManager: DailyLimitsManager

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
                .background(DesignSystem.Colors.surfaceSecondary)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(DesignSystem.Colors.surface.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}
#endif

// MARK: - Limit Reached Global Card
private struct LimitReachedGlobalCard: View {
    let tokens: [ApplicationToken]
    let waitAction: () -> Void
    let mindLockPlusAction: () -> Void

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

            VStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: waitAction) {
                    Label {
                        Text("Take a break")
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .mindLockButton(style: .secondary)

                Button(action: mindLockPlusAction) {
                    Label {
                        Text("Unlock impact")
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .mindLockButton(style: .primary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var previewTokens: [ApplicationToken] {
        Array(tokens.prefix(3))
    }

    private var limitTitle: String {
        let count = tokens.count
        if count == 1 { return "1 App Limited" }
        return "\(count) Apps Limited"
    }

    private var detailLine: String {    
        let count = tokens.count
        if count == 1 {
            return "1 app is being limited by MindLock."
        } else {
            return "\(count) apps are being limited by MindLock."
        }
    }
}

private struct MindLockPlusPromoCard: View {
    let selectedCharity: Charity?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("MindLock+ Impact")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(description)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button(action: action) {
                Label {
                    Text("Join MindLock+")
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "sparkles")
                }
                .frame(maxWidth: .infinity)
            }
            .mindLockButton(style: .primary)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var description: String {
        if let charity = selectedCharity {
            return """
turn your time saved into real-world impact:
- Earn streaks
- accumulate impact points
- unlock donations to \(charity.name).
"""
        }
        return """
turn your time saved into real-world impact:
- Earn streaks
- accumulate impact points
- unlock donations to your chosen charity.
"""
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
                        .background(DesignSystem.Colors.surfaceSecondary)
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
                    .background(DesignSystem.Colors.surfaceSecondary)
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
        // Try to load from the main screen time manager first (current session)
        localSelection = screenTimeManager.selectedApps
        
        // If that's empty, try to load from saved data
        if localSelection.applicationTokens.isEmpty {
            if let data = UserDefaults.standard.data(forKey: "selectedApps") {
                do {
                    localSelection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
                } catch {
                    print("❌ Failed to load selected apps: \(error)")
                    localSelection = FamilyActivitySelection()
                }
            }
        }
        
        // Build UI time limits from active/pending limits (not UserDefaults)
        var uiLimits: [String: Int] = [:]
        for token in localSelection.applicationTokens {
            let id = token.identifier
            if let seconds = limitsManager.getCurrentLimit(for: token) {
                uiLimits[id] = max(1, Int(seconds) / 60)
            } else if let pSeconds = limitsManager.getPendingLimit(for: token) {
                uiLimits[id] = max(1, Int(pSeconds) / 60)
            } else {
                uiLimits[id] = 20
            }
        }
        appTimeLimits = uiLimits

        // Capture originals for dirty-state detection
        originalSelection = localSelection
        originalTimeLimits = appTimeLimits

    }
    
    private func saveAppLimitsWithPolicy() {
        pendingImmediateOps.removeAll(); pendingDeferredOps.removeAll()
        let currentTokens = Set(screenTimeManager.selectedApps.applicationTokens.map { $0.identifier })
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
            .background(DesignSystem.Colors.surface)
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
        .background(DesignSystem.Colors.background.ignoresSafeArea())
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
