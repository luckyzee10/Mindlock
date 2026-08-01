import SwiftUI
import StoreKit

struct UnlockPromptView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var paymentManager = PaymentManager()
    @State private var purchaseErrorMessage: String?
    @State private var showingPurchaseError = false
    @State private var showingRestoreSuccess = false
    @State private var subscriptionActive = SharedSettings.isSubscriptionActive()
    @State private var selectedProductId: String?

    private let privacyPolicyURL = URL(string: "https://luckyzee10.github.io/mindlock-website/privacy.html")!
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

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
            AnalyticsService.shared.track(.paywallViewed, properties: [
                "subscription_active": .bool(subscriptionActive),
                "placement": .string("unlock_prompt")
            ])
            Task {
                await paymentManager.loadProductsIfNeeded()
                selectDefaultProductIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedSettings.subscriptionStatusChangedNotification)) { _ in
            subscriptionActive = SharedSettings.isSubscriptionActive()
        }
        .alert("Purchase Issue", isPresented: $showingPurchaseError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(purchaseErrorMessage ?? "Something went wrong. Please try again.")
        })
        .alert("Purchases Restored", isPresented: $showingRestoreSuccess, actions: {
            Button("OK", role: .cancel) { dismiss() }
        }, message: {
            Text("Your MindLock+ subscription is active on this device.")
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
                 ? "Your subscription includes language unlocks, enhanced analytics, and expanded blocking controls."
                 : "Turn blocked moments into better habits with deeper analytics, stronger schedules, and language unlocks.")
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
                title: "Track your journey.",
                detail: "Follow Spanish lessons, progress, XP, and completed units."
            )
            benefitRow(
                icon: "text.book.closed.fill",
                title: "Earn extra time by learning.",
                detail: "Unlock more app time through quick language practice."
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
            if !subscriptionActive {
                planOptions
            }

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
            .disabled(subscriptionActive || paymentManager.isProcessing || selectedProduct == nil)

            if !subscriptionActive {
                Text(subscriptionFinePrint)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            legalLinks

            if let failureMessage = failureMessage {
                Text(failureMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                }

            Button("Restore purchases") {
                restoreTapped()
            }
            .font(DesignSystem.Typography.callout.weight(.semibold))
            .foregroundColor(DesignSystem.Colors.primary)
            .disabled(paymentManager.isProcessing)
        }
        .frame(maxWidth: .infinity)
    }

    private var planOptions: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if let annual = paymentManager.annualProduct {
                planOptionCard(for: annual, isHighlighted: true)
            }
            if let monthly = paymentManager.monthlyProduct {
                planOptionCard(for: monthly, isHighlighted: false)
            }
            ForEach(otherProducts, id: \.id) { product in
                planOptionCard(for: product, isHighlighted: false)
            }
        }
    }

    private func planOptionCard(for product: Product, isHighlighted: Bool) -> some View {
        let isSelected = selectedProductId == product.id
        let trialText = product.freeTrialDescription?.uppercased()

        return Button {
            selectedProductId = product.id
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(product.subscriptionTitle)
                                .font(DesignSystem.Typography.headline.weight(.heavy))
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            if let savings = annualSavingsText(for: product), isHighlighted {
                                Text(savings)
                                    .font(DesignSystem.Typography.caption.weight(.heavy))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(DesignSystem.Colors.success)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(product.freeTrialDescription ?? product.billingSummary)
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text(product.renewalDisclosure)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(product.displayPrice)
                            .font(DesignSystem.Typography.headline.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text(product.perDayPriceText)
                            .font(DesignSystem.Typography.callout.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.12 : 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(isSelected ? DesignSystem.Colors.success : Color.white.opacity(0.14), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: isSelected ? DesignSystem.Colors.success.opacity(0.22) : .clear, radius: 18, x: 0, y: 10)

                if let trialText, isHighlighted {
                    Text(trialText)
                        .font(DesignSystem.Typography.caption.weight(.heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(DesignSystem.Colors.success)
                        .clipShape(Capsule())
                        .offset(x: -18, y: -13)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var legalLinks: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Link("Privacy Policy", destination: privacyPolicyURL)
            Text("•")
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Link("Terms of Use (EULA)", destination: termsURL)
        }
        .font(DesignSystem.Typography.caption.weight(.semibold))
        .foregroundColor(DesignSystem.Colors.primary)
        .padding(.top, DesignSystem.Spacing.xs)
    }

    private func subscribeTapped() {
        guard !subscriptionActive else { return }
        Task {
            await executePurchase()
        }
    }

    private func restoreTapped() {
        AnalyticsService.shared.track(.restoreTapped, properties: [
            "placement": .string("unlock_prompt")
        ])
        Task {
            await executeRestore()
        }
    }

    private func executePurchase() async {
        do {
            guard let selectedProduct else {
                throw PaymentError.productUnavailable
            }
            try await paymentManager.purchaseSubscription(product: selectedProduct)
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

    private func executeRestore() async {
        do {
            try await paymentManager.restorePurchases()
            await MainActor.run {
                subscriptionActive = SharedSettings.isSubscriptionActive()
                showingRestoreSuccess = subscriptionActive
            }
        } catch {
            purchaseErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showingPurchaseError = true
        }
    }

    private var buttonTitle: String {
        if selectedProduct?.hasFreeTrial == true {
            return "Start Free Trial"
        }
        if let price = selectedProduct?.displayPrice {
            return "Join MindLock+ • \(price)"
        }
        return "Join MindLock+"
    }

    private var subscriptionFinePrint: String {
        guard let product = selectedProduct else {
            return "Subscription details load from the App Store."
        }

        if let trial = product.freeTrialDescription {
            return "\(trial). Then \(product.displayPrice) per \(product.subscriptionPeriodDescription). Cancel anytime."
        }

        return "\(product.displayPrice) per \(product.subscriptionPeriodDescription). Cancel anytime."
    }

    private var selectedProduct: Product? {
        if let selectedProductId,
           let product = paymentManager.availableProducts.first(where: { $0.id == selectedProductId }) {
            return product
        }
        return paymentManager.annualProduct ?? paymentManager.primaryProduct
    }

    private var otherProducts: [Product] {
        paymentManager.availableProducts.filter { product in
            product.id != paymentManager.annualProduct?.id && product.id != paymentManager.monthlyProduct?.id
        }
    }

    private func selectDefaultProductIfNeeded() {
        guard selectedProductId == nil else { return }
        selectedProductId = paymentManager.annualProduct?.id ?? paymentManager.primaryProduct?.id
    }

    private func annualSavingsText(for product: Product) -> String? {
        guard product.id == paymentManager.annualProduct?.id,
              let monthly = paymentManager.monthlyProduct else {
            return nil
        }

        let annualizedMonthly = monthly.price * Decimal(12)
        guard annualizedMonthly > product.price else { return nil }

        let discount = 1 - (product.price.nsDecimalNumber.doubleValue / annualizedMonthly.nsDecimalNumber.doubleValue)
        let percent = Int((discount * 100).rounded())
        return "SAVE \(percent)%"
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

private extension Product {
    var subscriptionTitle: String {
        "MindLock+ \(planTitle)"
    }

    var planTitle: String {
        switch subscription?.subscriptionPeriod.unit {
        case .year:
            return "Yearly"
        case .month:
            return "Monthly"
        case .week:
            return "Weekly"
        case .day:
            return "Daily"
        case nil:
            return "MindLock+"
        @unknown default:
            return "MindLock+"
        }
    }

    var hasFreeTrial: Bool {
        subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    var freeTrialDescription: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }
        return "\(offer.period.readableDescription) free"
    }

    var subscriptionPeriodDescription: String {
        subscription?.subscriptionPeriod.readableUnitDescription ?? "subscription period"
    }

    var billingSummary: String {
        "\(subscriptionLengthDescription) • \(displayPrice)"
    }

    var renewalDisclosure: String {
        switch subscription?.subscriptionPeriod.unit {
        case .year:
            return "Auto-renews annually until canceled."
        case .month:
            return "Auto-renews monthly until canceled."
        case .week:
            return "Auto-renews weekly until canceled."
        case .day:
            return "Auto-renews daily until canceled."
        case nil:
            return "Auto-renews until canceled."
        @unknown default:
            return "Auto-renews until canceled."
        }
    }

    var subscriptionLengthDescription: String {
        guard let period = subscription?.subscriptionPeriod else {
            return "Auto-renewable subscription"
        }
        return "\(period.readableDescription) subscription"
    }

    var perDayPriceText: String {
        guard let period = subscription?.subscriptionPeriod else {
            return ""
        }
        let dayCount = Decimal(period.approximateDayCount)
        guard dayCount > 0 else { return "" }
        let perDay = price / dayCount
        return "\(perDay.formatted(priceFormatStyle))/day"
    }
}

private extension Product.SubscriptionPeriod {
    var readableDescription: String {
        let unitName = unit.readableName(plural: value != 1)
        return "\(value) \(unitName)"
    }

    var readableUnitDescription: String {
        unit.readableName(plural: false)
    }

    var approximateDayCount: Int {
        switch unit {
        case .day:
            return value
        case .week:
            return value * 7
        case .month:
            return value * 30
        case .year:
            return value * 365
        @unknown default:
            return value
        }
    }
}

private extension Product.SubscriptionPeriod.Unit {
    func readableName(plural: Bool) -> String {
        switch self {
        case .day:
            return plural ? "days" : "day"
        case .week:
            return plural ? "weeks" : "week"
        case .month:
            return plural ? "months" : "month"
        case .year:
            return plural ? "years" : "year"
        @unknown default:
            return plural ? "periods" : "period"
        }
    }
}

private extension Decimal {
    var nsDecimalNumber: NSDecimalNumber {
        NSDecimalNumber(decimal: self)
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
