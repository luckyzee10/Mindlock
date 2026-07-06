import SwiftUI
import StoreKit

struct UnlockPromptView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var paymentManager = PaymentManager()
    @State private var purchaseErrorMessage: String?
    @State private var showingPurchaseError = false
    @State private var subscriptionActive = SharedSettings.isSubscriptionActive()

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        comparisonCard
                        heroSection
                        benefitsList
                        socialProof
                        subscriptionCTA

                        Button("Not now") { dismiss() }
                            .font(DesignSystem.Typography.body.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task { await paymentManager.loadProductsIfNeeded() }
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

    private var comparisonCard: some View {
        HStack(spacing: 0) {
            comparisonColumn(
                title: "Before",
                value: "6h 32m",
                bars: [0.58, 0.78, 0.72, 0.52],
                emphasized: false
            )
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1)
                .padding(.vertical, DesignSystem.Spacing.md)
            comparisonColumn(
                title: "After",
                value: "1h 49m",
                bars: [0.24, 0.32, 0.28, 0.22],
                emphasized: true
            )
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.30),
                            DesignSystem.Colors.success.opacity(0.15),
                            Color.black.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: DesignSystem.Colors.primary.opacity(0.22), radius: 28, x: 0, y: 14)
    }

    private func comparisonColumn(title: String, value: String, bars: [CGFloat], emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.white.opacity(0.84))
                Text(value)
                    .font(.system(size: 29, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(alignment: .bottom, spacing: 9) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(emphasized ? DesignSystem.Colors.success : DesignSystem.Colors.primary)
                        .frame(width: 18, height: 82 * height)
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.white.opacity(0.28))
                                .frame(height: 8)
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text(subscriptionActive ? "MindLock+ is active" : "Earn more time back")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subscriptionActive
                 ? "Your subscription includes exercise unlocks, enhanced analytics, and expanded blocking controls."
                 : "Turn blocked moments into better habits with deeper analytics, stronger schedules, and exercise unlocks.")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            benefitRow(
                icon: "lock.fill",
                title: "Focus, uninterrupted.",
                detail: "Create stronger blocks around the apps that pull you back."
            )
            benefitRow(
                icon: "chart.bar.fill",
                title: "Understand your habits.",
                detail: "See real Screen Time usage directly in the Usage tab."
            )
            benefitRow(
                icon: "figure.strengthtraining.traditional",
                title: "Earn extra time with movement.",
                detail: "Unlock more app time through quick verified exercise challenges."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                (Text(title).bold() + Text(" \(detail)"))
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var socialProof: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)
                }
            }
            Text("Built for people who want their phone to work for them.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var subscriptionCTA: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
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
            .premiumPaywallButton()
            .disabled(subscriptionActive || paymentManager.isProcessing || paymentManager.primaryProduct == nil)

            if let failureMessage = failureMessage {
                Text(failureMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func subscribeTapped() {
        guard !subscriptionActive else { return }
        Task {
            await executePurchase()
        }
    }

    private func executePurchase() async {
        do {
            try await paymentManager.purchaseSubscription()
            await MainActor.run {
                subscriptionActive = SharedSettings.isSubscriptionActive()
                dismiss()
            }
        } catch PaymentError.userCancelled {
            // no-op
        } catch {
            purchaseErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showingPurchaseError = true
        }
    }

    private var buttonTitle: String {
        if let price = paymentManager.primaryProduct?.displayPrice {
            return "Join MindLock+ • \(price)"
        }
        return "Join MindLock+"
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

private extension View {
    func premiumPaywallButton() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primary,
                        Color(red: 0.08, green: 0.48, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: DesignSystem.Colors.primary.opacity(0.42), radius: 18, x: 0, y: 10)
    }
}
