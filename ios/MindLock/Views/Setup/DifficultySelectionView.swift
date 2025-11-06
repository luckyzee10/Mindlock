import SwiftUI

struct DifficultySelectionView: View {
    @State private var selectedTier: PricingTier = .moderate
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Difficulty Level")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Choose how much you're willing to pay to unlock apps when you exceed your limits")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.lg)
                        
                        // Current Selection
                        CurrentDifficultyCard(tier: selectedTier)
                        
                        // Available Tiers
                        VStack(spacing: DesignSystem.Spacing.md) {
                            HStack {
                                Text("Available Levels")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Spacer()
                            }
                            
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                DifficultyCard(
                                    tier: .easy,
                                    isSelected: selectedTier.name == PricingTier.easy.name,
                                    onSelect: { selectedTier = .easy }
                                )
                                
                                DifficultyCard(
                                    tier: .moderate,
                                    isSelected: selectedTier.name == PricingTier.moderate.name,
                                    onSelect: { selectedTier = .moderate }
                                )
                                
                                DifficultyCard(
                                    tier: .strict,
                                    isSelected: selectedTier.name == PricingTier.strict.name,
                                    onSelect: { selectedTier = .strict }
                                )
                            }
                        }
                        
                        // Info Section
                        DifficultyInfoCard()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSelection()
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentSelection()
        }
    }
    
    private func loadCurrentSelection() {
        if let tierName = UserDefaults.standard.string(forKey: "selectedPricingTier") {
            switch tierName {
            case "Easy Mode":
                selectedTier = .easy
            case "Strict Mode":
                selectedTier = .strict
            default:
                selectedTier = .moderate
            }
        }
    }
    
    private func saveSelection() {
        UserDefaults.standard.set(selectedTier.name, forKey: "selectedPricingTier")
    }
}

// MARK: - Current Difficulty Card
struct CurrentDifficultyCard: View {
    let tier: PricingTier
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Current Level")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                    .font(.system(size: 20))
            }
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                Text(tier.emoji)
                    .font(.system(size: 50))
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(tier.name)
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(tier.description)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Pricing Preview
            HStack {
                VStack(alignment: .center, spacing: 4) {
                    Text("10 minutes")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(tier.fifteenMinPrice)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("30 minutes")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(tier.thirtyMinPrice)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Full day")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(tier.fullDayPrice)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.success.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.success.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// MARK: - Difficulty Card
struct DifficultyCard: View {
    let tier: PricingTier
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var tierColor: Color {
        switch tier.name {
        case "Easy Mode":
            return DesignSystem.Colors.success
        case "Strict Mode":
            return DesignSystem.Colors.accent
        default:
            return DesignSystem.Colors.warning
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text(tier.emoji)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(tier.name)
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(tier.description)
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(tierColor)
                            .font(.system(size: 24))
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .font(.system(size: 24))
                    }
                }
                
                // Pricing Row
                HStack {
                    PriceColumn(duration: "10m", price: tier.fifteenMinPrice, color: tierColor)
                    
                    Spacer()
                    
                    PriceColumn(
                        duration: "30m",
                        price: tier.thirtyMinPrice,
                        color: tierColor
                    )
                    
                    Spacer()
                    
                    PriceColumn(
                        duration: "Full day",
                        price: tier.fullDayPrice,
                        color: tierColor
                    )
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(isSelected ? tierColor.opacity(0.05) : DesignSystem.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(isSelected ? tierColor.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}

// MARK: - Price Column
struct PriceColumn: View {
    let duration: String
    let price: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(duration)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(price)
                .font(DesignSystem.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Difficulty Info Card
struct DifficultyInfoCard: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(DesignSystem.Colors.warning)
                    .font(.system(size: 20))
                
                Text("How Difficulty Works")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                DifficultyInfoRow(
                    icon: "timer",
                    title: "Easy Mode",
                    description: "Lower costs make it easier to unlock apps, but may be less effective at changing habits"
                )
                
                DifficultyInfoRow(
                    icon: "scale.3d",
                    title: "Balanced",
                    description: "Moderate pricing provides good balance between accessibility and habit formation"
                )
                
                DifficultyInfoRow(
                    icon: "lock.fill",
                    title: "Strict Mode",
                    description: "Higher costs create stronger motivation to stick to your limits"
                )
                
                Divider()
                    .background(DesignSystem.Colors.textTertiary.opacity(0.3))
                
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20)
                    
                    Text("Remember: A percentage of every unlock fee goes to your chosen charity, so even your slip-ups create positive impact!")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// MARK: - Difficulty Info Row
struct DifficultyInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.primary)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    DifficultySelectionView()
} 
