import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @StateObject private var screenTimeManager = ScreenTimeManager()
    @State private var isShowingPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingHelp = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header illustration
                    headerSection
                    
                    // Instruction text
                    instructionSection
                    
                    // Authorization status
                    authorizationStatusSection
                    
                    // App selection section
                    selectionSection
                    
                    // Selected apps display
                    if !screenTimeManager.selectedApps.applicationTokens.isEmpty {
                        selectedAppsSection
                    }
                    
                    // Help section
                    if showingHelp {
                        helpSection
                    }
                    
                    Spacer(minLength: DesignSystem.Spacing.xl)
                    
                    // Continue button
                    continueButton
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .familyActivityPicker(
            isPresented: $isShowingPicker,
            selection: $screenTimeManager.selectedApps
        )
        .alert("Screen Time Error", isPresented: $showingError) {
            Button("Try Again") {
                Task {
                    await requestPermissionsWithRetry()
                }
            }
            Button("Help") {
                showingHelp = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await requestPermissionsIfNeeded()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                // Background gradient circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignSystem.Colors.primary.opacity(0.15),
                                DesignSystem.Colors.primary.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 120
                        )
                    )
                    .frame(width: 180, height: 180)
                
                // App icons illustration
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.surface)
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: DesignSystem.Shadows.medium.color,
                            radius: DesignSystem.Shadows.medium.radius,
                            x: DesignSystem.Shadows.medium.x,
                            y: DesignSystem.Shadows.medium.y
                        )
                    
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    private var instructionSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Choose Apps to Monitor")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.bold)
            
            Text("Select the social media and entertainment apps you want to set limits for. MindLock will help you stay mindful of your usage.")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    private var authorizationStatusSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 16, weight: .medium))
                
                Text(statusText)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                if screenTimeManager.authorizationStatus == .denied {
                    Button("Settings") {
                        openSettings()
                    }
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(statusColor.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)
            
            if let error = screenTimeManager.authorizationError {
                Text(error)
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }
    
    private var statusIcon: String {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return DesignSystem.Colors.success
        case .denied:
            return DesignSystem.Colors.error
        case .notDetermined:
            return DesignSystem.Colors.warning
        @unknown default:
            return DesignSystem.Colors.error
        }
    }
    
    private var statusText: String {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return "Screen Time access granted"
        case .denied:
            return "Screen Time access denied"
        case .notDetermined:
            return "Screen Time permission needed"
        @unknown default:
            return "Screen Time status unknown"
        }
    }
    
    private var selectionSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                if screenTimeManager.isAuthorized {
                    isShowingPicker = true
                } else {
                    Task {
                        await requestPermissionsWithRetry()
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(screenTimeManager.isAuthorized ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.warning.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: screenTimeManager.isAuthorized ? "plus.app" : "lock.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(screenTimeManager.isAuthorized ? DesignSystem.Colors.primary : DesignSystem.Colors.warning)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(screenTimeManager.isAuthorized ? "Select Apps" : "Grant Permission")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(screenTimeManager.isAuthorized ? "Tap to choose from your installed apps" : "Tap to enable Screen Time access")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .mindLockCard()
        }
    }
    
    private var selectedAppsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Selected Apps")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                    
                    Text("\(screenTimeManager.selectedApps.applicationTokens.count) apps selected")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button("Change") {
                        isShowingPicker = true
                    }
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .disabled(!screenTimeManager.isAuthorized)
                }
                
                Text("MindLock will monitor these apps and help you stay within your daily limits.")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.success.opacity(0.05))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Having Trouble?")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                helpItem(
                    icon: "1.circle.fill",
                    title: "Check Settings",
                    description: "Go to Settings > Screen Time and ensure it's enabled"
                )
                
                helpItem(
                    icon: "2.circle.fill",
                    title: "Restart App",
                    description: "Close and reopen MindLock, then try again"
                )
                
                helpItem(
                    icon: "3.circle.fill",
                    title: "Restart Device",
                    description: "Sometimes a device restart helps with Screen Time permissions"
                )
            }
            
            Button("Hide Help") {
                withAnimation {
                    showingHelp = false
                }
            }
            .font(DesignSystem.Typography.callout)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.md)
        .mindLockCard()
    }
    
    private func helpItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private var continueButton: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                setupComplete()
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Continue")
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .mindLockButton(style: .primary)
            .disabled(!canContinue)
            .opacity(canContinue ? 1.0 : 0.6)
            
            if !screenTimeManager.isAuthorized {
                Text("Screen Time permission required to continue")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.error)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var canContinue: Bool {
        screenTimeManager.isAuthorized && !screenTimeManager.selectedApps.applicationTokens.isEmpty
    }
    
    // MARK: - Actions
    
    private func requestPermissionsIfNeeded() async {
        if screenTimeManager.authorizationStatus == .notDetermined {
            await requestPermissionsWithRetry()
        }
    }
    
    private func requestPermissionsWithRetry() async {
        do {
            try await screenTimeManager.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func setupComplete() {
        // Save the selected apps
        screenTimeManager.updateSelectedApps(screenTimeManager.selectedApps)
        
        // Start monitoring
        do {
            try screenTimeManager.startMonitoring()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    AppSelectionView()
} 