import SwiftUI
import FamilyControls
import ManagedSettings

struct SetupView: View {
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var limitsManager = DailyLimitsManager.shared
    @State private var selectedCharity: Charity?
    @State private var selectedPricingTier: PricingTier = .moderate
    @State private var showingAppPicker = false
    @State private var showingAppLimits = false
    @State private var showingCharitySelection = false
    @State private var showingDifficultySelection = false
    @State private var appTimeLimits: [String: Int] = [:]
    // Unlock flow presentation from "limit reached" cards
    @State private var unlockSheetToken: SelectedAppToken?
    @State private var unlockPreferredDuration: UnlockDuration = .tenMinutes
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Setup")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Configure your app limits and preferences")
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
                            description: "Choose where your unlock fees go",
                            icon: "heart.fill",
                            status: selectedCharity?.name ?? "Not selected"
                        ) {
                            showingCharitySelection = true
                        }
                        
                        // Difficulty Settings Section
                        SetupSectionCard(
                            title: "Difficulty Level",
                            description: "How much to pay for unlock time",
                            icon: "slider.horizontal.3",
                            status: selectedPricingTier.name
                        ) {
                            showingDifficultySelection = true
                        }
                        
                        // Limit Reached Cards (show when any app has exceeded its limit)
                        if !reachedLimitTokens.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(Array(reachedLimitTokens.prefix(3)).sorted(by: { $0.identifier < $1.identifier }), id: \.identifier) { token in
                                    LimitReachedCard(
                                        token: token,
                                        onSelectDuration: { duration in
                                            unlockPreferredDuration = duration
                                            unlockSheetToken = SelectedAppToken(token: token)
                                        }
                                    )
                                }
                                if reachedLimitTokens.count > 3 {
                                    let extra = reachedLimitTokens.count - 3
                                    Button("and \(extra) more limits reached") {
                                        showingAppLimits = true
                                    }
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        
                        // Testing and troubleshooting UI removed for production
                        
                        // Quick Stats
                        if !screenTimeManager.selectedApps.applicationTokens.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("Current Configuration")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                HStack(spacing: DesignSystem.Spacing.lg) {
                                    QuickStatCard(
                                        title: "\(screenTimeManager.selectedApps.applicationTokens.count)",
                                        subtitle: "Apps Limited",
                                        color: DesignSystem.Colors.primary
                                    )
                                    
                                    QuickStatCard(
                                        title: selectedPricingTier.name,
                                        subtitle: "Difficulty",
                                        color: DesignSystem.Colors.warning
                                    )
                                    
                                    QuickStatCard(
                                        title: selectedCharity?.name ?? "None",
                                        subtitle: "Charity",
                                        color: DesignSystem.Colors.success
                                    )
                                }
                            }
                            .padding(.top, DesignSystem.Spacing.lg)
                        }

#if DEBUG
                        SetupDebugActions(limitsManager: limitsManager)
#endif
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAppLimits) {
            AppLimitsSetupView(isPresented: $showingAppLimits)
        }
        .sheet(item: $unlockSheetToken) { wrapper in
            UnlockFlowView(
                blockedApp: wrapper.token,
                preferredDuration: unlockPreferredDuration,
                onDismiss: { unlockSheetToken = nil },
                onUnlockPurchased: { unlockSheetToken = nil }
            )
        }
        .sheet(isPresented: $showingCharitySelection) {
            SetupCharitySelectionView()
        }
        .sheet(isPresented: $showingDifficultySelection) {
            DifficultySelectionView()
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
        .onChange(of: showingDifficultySelection) { _, isShowing in
            if !isShowing {
                // Reload difficulty selection when sheet closes
                loadUserPreferences()
                print("⚖️ Difficulty selection sheet closed, reloading preferences")
            }
        }
    }
    
    private func loadUserPreferences() {
        // Load pricing tier
        if let pricingData = UserDefaults.standard.data(forKey: "userPricingTier"),
           let pricing = try? JSONDecoder().decode(PricingTier.self, from: pricingData) {
            limitsManager.userPricingTier = pricing
            selectedPricingTier = pricing
        }
        
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
        
        print("📱 Loaded user preferences - Pricing: \(selectedPricingTier.name), Charity: \(selectedCharity?.name ?? "None")")
    }

    // Tokens that have reached today's limit (union of computed + recent blocks)
    private var reachedLimitTokens: [ApplicationToken] {
        let selected = screenTimeManager.selectedApps.applicationTokens
        var set = Set<ApplicationToken>()
        for t in selected { if limitsManager.hasExceededLimit(for: t) { set.insert(t) } }
        for t in limitsManager.recentlyBlockedTokens { if selected.contains(t) { set.insert(t) } }
        return Array(set)
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

// MARK: - Setup Section Card
struct SetupSectionCard: View {
    let title: String
    let description: String
    let icon: String
    let status: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
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

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(subtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// Wrapper to use ApplicationToken with .sheet(item:)
private struct SelectedAppToken: Identifiable, Equatable {
    let id = UUID()
    let token: ApplicationToken
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

// MARK: - Limit Reached Card
private struct LimitReachedCard: View {
    let token: ApplicationToken
    let onSelectDuration: (UnlockDuration) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Label(token).labelStyle(.iconOnly).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've reached your daily limit on")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(Application(token: token).localizedDisplayName ?? "This app")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
            }
            HStack(spacing: DesignSystem.Spacing.lg) {
                DurationPill(text: "10m", color: DesignSystem.Colors.success) { onSelectDuration(.tenMinutes) }
                DurationPill(text: "30m", color: DesignSystem.Colors.warning) { onSelectDuration(.thirtyMinutes) }
                DurationPill(text: "Full Day", color: DesignSystem.Colors.accent) { onSelectDuration(.fullDay) }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

private struct DurationPill: View {
    let text: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DesignSystem.Typography.body)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
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
    @State private var showUnlockSheetForToken: SelectedAppToken?
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
        .sheet(item: $showUnlockSheetForToken) { wrapper in
            UnlockFlowView(
                blockedApp: wrapper.token,
                onDismiss: { showUnlockSheetForToken = nil },
                onUnlockPurchased: { showUnlockSheetForToken = nil }
            )
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
                                reached: limitsManager.hasExceededLimit(for: token),
                                onUnlock: { showUnlockSheetForToken = SelectedAppToken(token: token) }
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
    let onUnlock: () -> Void
    
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

            if reachedLimit {
                Button("Unlock") { onUnlock() }
                    .font(DesignSystem.Typography.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.success.opacity(0.2))
                    .foregroundColor(DesignSystem.Colors.success)
                    .cornerRadius(8)
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
    let onUnlock: () -> Void

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
            reachedLimit: reached,
            onUnlock: onUnlock
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

// MARK: - Instant Change Paywall (simple)
private struct InstantChangePaywallView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    @ObservedObject private var limitsManager = DailyLimitsManager.shared
    @State private var selectedCharity: Charity?

    var middlePrice: String {
        limitsManager.userPricingTier.thirtyMinPrice
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Card
                VStack(spacing: DesignSystem.Spacing.lg) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "lock.open.trianglebadge.exclamationmark")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accent)
                        Text("Apply Changes Now")
                            .font(DesignSystem.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Some limits have been deferred to tomorrow to keep you in line with your goals. You can apply changes now and support \(selectedCharity?.name ?? "your chosen charity"). Would you like to do so now?")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    // Charity selection (similar to unlock flow)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        if let charity = selectedCharity {
                            HStack {
                                Text("Supporting")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                Spacer()
                                Button("Change") { selectedCharity = nil }
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Text(charity.emoji).font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(charity.name)
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    Text(charity.description)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.primary.opacity(0.08))
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        } else {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Choose a charity")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        ForEach(Charity.popularCharities) { charity in
                                            Button(action: {
                                                selectedCharity = charity
                                                UserDefaults.standard.set(charity.id, forKey: "selectedCharityId")
                                            }) {
                                                HStack(spacing: 8) {
                                                    Text(charity.emoji)
                                                    Text(charity.name)
                                                        .font(DesignSystem.Typography.caption)
                                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(DesignSystem.Colors.surface)
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(middlePrice)
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("one-time")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Button("Confirm and Apply Now") { onConfirm(); isPresented = false }
                        .mindLockButton(style: .primary)
                    Button("Cancel") { isPresented = false }
                        .mindLockButton(style: .secondary)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.CornerRadius.lg)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(DesignSystem.Spacing.lg)
            }
        }
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "selectedCharityId"),
               let charity = Charity.popularCharities.first(where: { $0.id == id }) {
                selectedCharity = charity
            }
        }
    }
}

#Preview {
    SetupView()
} 
