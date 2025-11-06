import SwiftUI
import FamilyControls
import ManagedSettings

struct UnlockFlowView: View {
    let blockedApp: ApplicationToken
    var preferredDuration: UnlockDuration? = nil
    let onDismiss: () -> Void
    let onUnlockPurchased: () -> Void
    
    @ObservedObject private var limitsManager = DailyLimitsManager.shared
    @State private var selectedCharity: Charity?
    @State private var selectedDuration: UnlockDuration = .tenMinutes
    @State private var showingPayment = false
    @State private var isProcessingPayment = false
    @State private var userPricingTier: PricingTier = .moderate
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // App info and limit reached
                    limitReachedSection
                    
                    // Charity selection
                    if selectedCharity == nil {
                        charitySelectionSection
                    } else {
                        selectedCharitySection
                        
                        // Duration and pricing
                        durationSelectionSection
                        
                        // Action buttons
                        actionButtonsSection
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .onAppear {
            loadUserPricingTier()
            loadDefaultCharity()
            if let pref = preferredDuration { selectedDuration = pref }
        }
    }
    
    // MARK: - View Components
    
    private var limitReachedSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // App icon and name
            HStack(spacing: DesignSystem.Spacing.md) {
                Label(blockedApp)
                    .labelStyle(.iconOnly)
                    .frame(width: 50, height: 50)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Time's up")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                                         if let limit = limitsManager.getCurrentLimit(for: blockedApp) {
                         Text("You've used your \(formatTime(limit)) daily limit")
                             .font(DesignSystem.Typography.body)
                             .foregroundColor(DesignSystem.Colors.textSecondary)
                     }
                }
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
    }
    
    private var charitySelectionSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Turn this moment into impact")
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose who benefits from your extra time")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Charity.popularCharities) { charity in
                        CharityUnlockCard(charity: charity) {
                            withAnimation(.easeInOut) {
                                selectedCharity = charity
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var selectedCharitySection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Supporting")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Spacer()
                Button("Change") {
                    withAnimation(.easeInOut) {
                        selectedCharity = nil
                    }
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            }
            
            if let charity = selectedCharity {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text(charity.emoji)
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(charity.name)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(charity.description)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
    }
    
    private var durationSelectionSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Choose your extra time")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(UnlockDuration.allCases, id: \.self) { duration in
                                         UnlockDurationCard(
                         duration: duration,
                         isSelected: selectedDuration == duration,
                         charity: selectedCharity!,
                         pricingTier: userPricingTier
                     ) {
                         selectedDuration = duration
                     }
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: proceedToPayment) {
                HStack {
                    if isProcessingPayment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Continue with \(selectedDuration.displayName)")
                        Spacer()
                        Text(selectedDuration.price(for: userPricingTier))
                    }
                }
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.white)
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.lg)
            }
            .disabled(isProcessingPayment)
            
            Button("I'm done for today") {
                onDismiss()
            }
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Actions
    
    private func proceedToPayment() {
        guard let charity = selectedCharity else { return }
        print("🛒 UnlockFlowView: proceedToPayment tapped for \(blockedApp.identifier.prefix(8))… duration=\(selectedDuration.displayName)")
        Task { [weak limitsManager] in
            guard let limitsManager else {
                print("🛒 UnlockFlowView: limitsManager deallocated before purchase.")
                return
            }
            isProcessingPayment = true
            print("🛒 UnlockFlowView: isProcessingPayment set true")
            do {
                let duration = selectedDuration.duration
                let amount = selectedDuration.priceValue(for: userPricingTier)
                print("🛒 UnlockFlowView: invoking purchaseUnlock (duration=\(duration) amount=\(amount))")
                try await limitsManager.purchaseUnlock(
                    for: blockedApp,
                    duration: duration,
                    amount: amount,
                    charity: charity
                )
                print("🛒 UnlockFlowView: purchaseUnlock returned successfully")
                
                await MainActor.run {
                    // Success message
                    let minutes = Int(selectedDuration.duration / 60)
                    let appName = Application(token: blockedApp).localizedDisplayName ?? "your app"
                    let message = "Unlock confirmed. \(minutes) minute\(minutes == 1 ? "" : "s") added to \(appName). You also made a positive impact!"
                    let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in onUnlockPurchased() })
                    UIApplication.shared.topMostViewController()?.present(alert, animated: true)
                    NotificationManager.shared.postUnlockNotification(appToken: blockedApp, minutes: minutes)
                }
            } catch {
                print("❌ Unlock purchase failed: \(error)")
                // TODO: Show error alert
            }
            
            isProcessingPayment = false
            print("🛒 UnlockFlowView: isProcessingPayment reset false")
        }
    }
    
    // MARK: - Helper Methods

    private func loadUserPricingTier() {
        if let tierName = UserDefaults.standard.string(forKey: "selectedPricingTier") {
            if let tier = PricingTier.allTiers.first(where: { $0.name == tierName }) {
                userPricingTier = tier
            }
        }
    }
    
    private func loadDefaultCharity() {
        if let charityId = UserDefaults.standard.string(forKey: "selectedCharityId"),
           let charity = Charity.popularCharities.first(where: { $0.id == charityId }) {
            selectedCharity = charity
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Unlock Duration Model

enum UnlockDuration: CaseIterable {
    case tenMinutes
    case thirtyMinutes
    case fullDay
    
    var displayName: String {
        switch self {
        case .tenMinutes: return "10 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .fullDay: return "Rest of day"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .tenMinutes: return 10 * 60
        case .thirtyMinutes: return 30 * 60
        case .fullDay: return 8 * 60 * 60 // approximate rest of day
        }
    }
    
    func price(for pricingTier: PricingTier) -> String {
        switch self {
        case .tenMinutes: return pricingTier.fifteenMinPrice
        case .thirtyMinutes: return pricingTier.thirtyMinPrice
        case .fullDay: return pricingTier.fullDayPrice
        }
    }
    
    func priceValue(for pricingTier: PricingTier) -> Double {
        let priceString = price(for: pricingTier)
        let cleanPrice = priceString.replacingOccurrences(of: "$", with: "")
        return Double(cleanPrice) ?? 0.0
    }
    
    func impactDescription(for pricingTier: PricingTier) -> String {
        let amount = priceValue(for: pricingTier)
        let charityAmount = amount * 0.5 // 50% goes to charity
        let meals = Int(charityAmount * 2) // Assume $0.50 = 1 meal
        return "Funds \(meals) meal\(meals == 1 ? "" : "s")"
    }
}

// MARK: - Supporting Views

struct CharityUnlockCard: View {
    let charity: Charity
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Text(charity.emoji)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(charity.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(charity.description)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }
}

struct UnlockDurationCard: View {
    let duration: UnlockDuration
    let isSelected: Bool
    let charity: Charity
    let pricingTier: PricingTier
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(duration.displayName)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(duration == .fullDay ? "Rest of day" : "\(Int(duration.duration / 60)) minutes")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                                 VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                     Text(duration.price(for: pricingTier))
                         .font(DesignSystem.Typography.headline)
                         .foregroundColor(DesignSystem.Colors.textPrimary)
                     
                     Text(duration.impactDescription(for: pricingTier))
                         .font(DesignSystem.Typography.caption)
                         .foregroundColor(DesignSystem.Colors.success)
                 }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? DesignSystem.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

//#Preview {
//    UnlockFlowView(
//        blockedApp: ApplicationToken(),
//        onDismiss: {},
//        onUnlockPurchased: {}
//    )
//}
