import SwiftUI

struct UnlockPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: UnlockOption?
    @State private var showingLearnMore = false
    @State private var isAnimating = false
    
    private let selectedCharity = "Clean Water Fund"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Main message
                    messageSection
                    
                    // Unlock options
                    unlockOptionsSection
                    
                    // Charity section
                    charitySection
                    
                    Spacer(minLength: DesignSystem.Spacing.xl)
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.spring) {
                isAnimating = true
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // App icon/illustration
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accent)
            }
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .animation(DesignSystem.Animation.spring, value: isAnimating)
            
            Text("Time's Up!")
                .font(DesignSystem.Typography.title1)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.top, DesignSystem.Spacing.xl)
    }
    
    private var messageSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("You've reached your daily limit for social apps")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Text("Choose an unlock option below to continue using your apps. A portion of your payment supports charity.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .opacity(isAnimating ? 1.0 : 0.0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(DesignSystem.Animation.gentle.delay(0.3), value: isAnimating)
    }
    
    private var unlockOptionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Unlock Options")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(UnlockOption.allOptions, id: \.id) { option in
                UnlockOptionCard(
                    option: option,
                    isSelected: selectedOption?.id == option.id
                ) {
                    withAnimation(DesignSystem.Animation.gentle) {
                        selectedOption = option
                    }
                }
            }
        }
        .opacity(isAnimating ? 1.0 : 0.0)
        .offset(y: isAnimating ? 0 : 30)
        .animation(DesignSystem.Animation.gentle.delay(0.5), value: isAnimating)
    }
    
    private var charitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Supporting: \(selectedCharity)")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "heart.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("10% of your payment goes to charity")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Button("Learn more about \(selectedCharity)") {
                        showingLearnMore = true
                    }
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.success.opacity(0.05))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                handleUnlockPurchase()
            }) {
                HStack {
                    Image(systemName: "unlock.fill")
                    Text("Unlock for \(selectedOption?.price ?? "$0.99")")
                        .fontWeight(.semibold)
                }
            }
            .mindLockButton(style: .primary)
            .disabled(selectedOption == nil)
            .opacity(selectedOption == nil ? 0.6 : 1.0)
            
            Button("Maybe Later") {
                dismiss()
            }
            .mindLockButton(style: .secondary)
        }
    }
    
    private func handleUnlockPurchase() {
        guard let option = selectedOption else { return }
        
        // TODO: Implement Apple In-App Purchase
        print("🔓 Attempting to unlock for \(option.duration) at \(option.price)")
        print("💝 \(option.charityAmount) will go to \(selectedCharity)")
        
        // For now, just dismiss
        dismiss()
    }
}

struct UnlockOptionCard: View {
    let option: UnlockOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Option details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(option.duration)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Charity contribution: \(option.charityAmount)")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Price
                Text(option.price)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textPrimary)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .mindLockCard()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(
                    isSelected ? DesignSystem.Colors.primary : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(
            color: isSelected ? DesignSystem.Colors.primary.opacity(0.2) : DesignSystem.Shadows.small.color,
            radius: isSelected ? 8 : DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
        .animation(DesignSystem.Animation.gentle, value: isSelected)
    }
}

// MARK: - Data Models

struct UnlockOption: Equatable {
    let id = UUID()
    let duration: String
    let price: String
    let charityAmount: String
    let unlockMinutes: Int
    
    // Implement Equatable
    static func == (lhs: UnlockOption, rhs: UnlockOption) -> Bool {
        lhs.id == rhs.id
    }
    
    static let allOptions = [
        UnlockOption(duration: "10 minutes", price: "$0.99", charityAmount: "$0.10", unlockMinutes: 10),
        UnlockOption(duration: "30 minutes", price: "$1.99", charityAmount: "$0.20", unlockMinutes: 30),
        UnlockOption(duration: "1 hour", price: "$2.99", charityAmount: "$0.30", unlockMinutes: 60),
        UnlockOption(duration: "2 hours", price: "$4.99", charityAmount: "$0.50", unlockMinutes: 120)
    ]
}

#Preview {
    UnlockPromptView()
} 
