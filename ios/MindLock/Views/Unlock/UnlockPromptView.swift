import SwiftUI
import FamilyControls
import ManagedSettings
import StoreKit
import UIKit

struct UnlockPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var limitsManager: DailyLimitsManager
    let appToken: ApplicationToken

    @StateObject private var paymentManager = PaymentManager()
    @State private var selectedCharity: Charity?
    @State private var showingCharityPicker = false
    @State private var purchaseErrorMessage: String?
    @State private var showingPurchaseError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    heroSection
                    selectedCharitySection
                    quickCharityList
                    unlockCTA
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
            loadProductsIfNeeded()
        }
        .alert("Purchase Failed", isPresented: $showingPurchaseError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(purchaseErrorMessage ?? "Something went wrong. Please try again.")
        })
    }

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("You’ve reached your limit")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(appDisplayName) is currently limited by MindLock.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Text("Temporarily relax your MindLock limits for the rest of today. MindLock donates 15% of net proceeds to your selected charity.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xl)
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

    private var unlockCTA: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: purchaseDayPass) {
                if paymentManager.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .mindLockButton(style: .primary)
            .disabled(paymentManager.isProcessing || paymentManager.availableProduct == nil)

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

    private func purchaseDayPass() {
        if selectedCharity == nil {
            showingCharityPicker = true
            return
        }
        guard let charity = selectedCharity else { return }
        Task {
            await executePurchase(with: charity)
        }
    }

    private func executePurchase(with charity: Charity) async {
        do {
            try await paymentManager.purchaseDayPass(for: charity)
            await MainActor.run {
                let unlockedMinutes = limitsManager.grantDayPass(charity: charity)
                if let unlockedMinutes {
                    NotificationManager.shared.postDayPassNotification(minutesUntilMidnight: unlockedMinutes)
                }
                dismiss()
            }
        } catch PaymentError.userCancelled {
            // no-op
        } catch {
            purchaseErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showingPurchaseError = true
        }
    }

    private func loadProductsIfNeeded() {
        Task {
            await paymentManager.loadProductIfNeeded()
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

    private var appDisplayName: String {
        Application(token: appToken).localizedDisplayName ?? "your apps"
    }

    private var buttonTitle: String {
        if let price = paymentManager.availableProduct?.displayPrice {
            return "Buy Day Pass • \(price)"
        }
        return "Buy Day Pass"
    }

    private var failureMessage: String? {
        if case .failed(let message) = paymentManager.purchaseState {
            return message
        }
        if case .pending = paymentManager.purchaseState {
            return "Your purchase is pending approval. You’ll be able to unlock once Apple finishes processing."
        }
        return nil
    }
}
