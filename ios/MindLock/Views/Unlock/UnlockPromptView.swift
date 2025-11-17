import SwiftUI
import StoreKit
import UIKit

struct UnlockPromptView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var paymentManager = PaymentManager()
    @State private var selectedCharity: Charity?
    @State private var showingCharityPicker = false
    @State private var purchaseErrorMessage: String?
    @State private var showingPurchaseError = false
    @State private var subscriptionActive = SharedSettings.isSubscriptionActive()
    @State private var impactPoints = SharedSettings.impactPoints()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    heroSection
                    impactSummary
                    Text("Stack up impact points to transform up to 20% of your plan into donations for the causes you choose.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    selectedCharitySection
                    quickCharityList
                    subscriptionCTA
                    Button("Not now") { dismiss() }
                        .font(DesignSystem.Typography.body.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCharityPicker, onDismiss: loadSelectedCharity) {
            SetupCharitySelectionView()
        }
        .onAppear {
            loadSelectedCharity()
            refreshImpactMetrics()
            Task { await paymentManager.loadProductsIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.analyticsUpdatedNotification)) { _ in
            refreshImpactMetrics()
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.subscriptionStatusChangedNotification)) { _ in
            subscriptionActive = SharedSettings.isSubscriptionActive()
        }
        .alert("Purchase Failed", isPresented: $showingPurchaseError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(purchaseErrorMessage ?? "Something went wrong. Please try again.")
        })
    }

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(subscriptionActive ? "MindLock+ active" : "You Focus, We Donate")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(subscriptionActive ? "Your subscription delivers enhanced analytics, unlimited time blocks, and transparent giving."
                 : "Join MindLock+ to use your focus to create change. The more you focus, the more we donate.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    private var impactSummary: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Impact points")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("\(impactPoints)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Multiplier ×\(SharedSettings.impactMultiplier(forStreak: impactPoints))")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 36))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

        }
        .padding()
        .background(DesignSystem.Colors.surface.opacity(0.7))
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var selectedCharitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Your selected charity")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            if let charity = selectedCharity {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    if let name = charity.logoAssetName, let uiImage = UIImage(named: name) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text(charity.emoji)
                            .font(.system(size: 36))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(charity.name)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text(charity.description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding()
                .background(DesignSystem.Colors.surface.opacity(0.9))
                .cornerRadius(DesignSystem.CornerRadius.lg)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("No charity selected yet.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Button("Choose a charity") { showingCharityPicker = true }
                        .mindLockButton(style: .secondary)
                }
                .padding()
                .background(DesignSystem.Colors.surface.opacity(0.9))
                .cornerRadius(DesignSystem.CornerRadius.lg)
            }
        }
    }

    private var quickCharityList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Change your charity")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                Button("See all") { showingCharityPicker = true }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Charity.popularCharities) { charity in
                    Button {
                        selectedCharity = charity
                        UserDefaults.standard.set(charity.id, forKey: "selectedCharityId")
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            if let name = charity.logoAssetName, let uiImage = UIImage(named: name) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            } else {
                                Text(charity.emoji)
                                    .font(.system(size: 26))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(charity.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(charity.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if selectedCharity?.id == charity.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                        .padding()
                        .background(DesignSystem.Colors.surface.opacity(selectedCharity?.id == charity.id ? 0.8 : 0.5))
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                    }
                }
            }
        }
    }

    private var subscriptionCTA: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Save Your Time, Save the World")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Button(action: subscribeTapped) {
                if paymentManager.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(subscriptionActive ? "MindLock+ active" : buttonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .mindLockButton(style: .primary)
            .disabled(subscriptionActive || paymentManager.isProcessing || paymentManager.primaryProduct == nil)

            if let failureMessage = failureMessage {
                Text(failureMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface.opacity(0.35))
        .cornerRadius(32)
    }

    private func subscribeTapped() {
        guard !subscriptionActive else { return }
        guard selectedCharity != nil else {
            showingCharityPicker = true
            return
        }
        Task {
            await executePurchase()
        }
    }

    private func executePurchase() async {
        guard let charity = selectedCharity else { return }
        do {
            try await paymentManager.purchaseSubscription(for: charity)
            await MainActor.run {
                subscriptionActive = true
                dismiss()
            }
        } catch PaymentError.userCancelled {
            // no-op
        } catch {
            purchaseErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showingPurchaseError = true
        }
    }

    private func loadSelectedCharity() {
        if let charityId = UserDefaults.standard.string(forKey: "selectedCharityId"),
           let charity = Charity.popularCharities.first(where: { $0.id == charityId }) {
            selectedCharity = charity
        } else {
            selectedCharity = nil
        }
    }

    private var buttonTitle: String {
        if let price = paymentManager.primaryProduct?.displayPrice {
            return "Join MindLock+ • \(price)"
        }
        return "Join MindLock+"
    }

    private func refreshImpactMetrics() {
        impactPoints = SharedSettings.impactPoints()
    }

    private var failureMessage: String? {
        if case .failed(let message) = paymentManager.purchaseState {
            return message
        }
        if case .pending = paymentManager.purchaseState {
            return "Your purchase is pending approval. You’ll be able to complete checkout once Apple finishes processing."
        }
        return nil
    }
}
