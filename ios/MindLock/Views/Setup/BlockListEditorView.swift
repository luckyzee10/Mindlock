import SwiftUI
import FamilyControls

struct BlockListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var localSelection = FamilyActivitySelection()
    @State private var showingPicker = false
    @AppStorage("tooltip.blockList.seen") private var blockListTooltipSeen = false
    @State private var showTooltip = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Apps on your block list are paused whenever a Time Block runs. This doesn’t affect App Limits—you can set those separately later.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Spacing.lg)

                if localSelection.applicationTokens.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("No apps selected yet.")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Tap the button below to add social media or entertainment apps you want MindLock to control during Time Blocks.")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Array(localSelection.applicationTokens).sorted { $0.identifier < $1.identifier }, id: \.identifier) { token in
                                BlockListAppRow(applicationToken: token)
                            }
                        }
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    }
                }

                Button(localSelection.applicationTokens.isEmpty ? "Add Apps" : "Add or Remove Apps") {
                    showingPicker = true
                }
                .mindLockButton(style: .primary)

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .navigationTitle("Block List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        screenTimeManager.updateSelectedApps(localSelection, reason: "block list editor")
                        dismiss()
                    }
                    .disabled(localSelection.applicationTokens.isEmpty)
                }
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $localSelection)
        .onAppear {
            localSelection = screenTimeManager.selectedApps
            let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingCompleted")
            if onboardingDone && !blockListTooltipSeen {
                showTooltip = true
            }
        }
        .overlay(alignment: .topTrailing) {
            if showTooltip {
                SetupTooltip(text: "Curate this list once. Every Time Block uses it to know which apps to pause.") {
                    showTooltip = false
                    blockListTooltipSeen = true
                }
                .padding()
            }
        }
    }
}
