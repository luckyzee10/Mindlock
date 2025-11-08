import SwiftUI
import UIKit

struct SetupCharitySelectionView: View {
    @State private var selectedCharity: Charity?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Your Charity")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Choose where your unlock fees go to make a difference")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.lg)
                        
                        // Current Selection (if any)
                        if let selectedCharity = selectedCharity {
                            CurrentCharityCard(charity: selectedCharity)
                            
                            Button("Choose later") {
                                clearSelection()
                            }
                            .mindLockButton(style: .ghost)
                        }
                        
                        // Available Charities
                        VStack(spacing: DesignSystem.Spacing.md) {
                            HStack {
                                Text("Available Organizations")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Spacer()
                            }
                            
                            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(Charity.popularCharities) { charity in
                                    CharityCard(
                                        charity: charity,
                                        isSelected: selectedCharity?.id == charity.id,
                                        onSelect: {
                                            selectCharity(charity)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Info Section
                        InfoCard()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedCharity == nil ? "Skip" : "Save") {
                        if selectedCharity != nil {
                            saveSelection()
                        } else {
                            clearSelection()
                        }
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
        if let charityId = UserDefaults.standard.string(forKey: "selectedCharityId"),
           let charity = Charity.popularCharities.first(where: { $0.id == charityId }) {
            selectedCharity = charity
        }
    }
    
    private func selectCharity(_ charity: Charity) {
        selectedCharity = charity
    }
    
    private func saveSelection() {
        if let charity = selectedCharity {
            UserDefaults.standard.set(charity.id, forKey: "selectedCharityId")
        }
    }
    
    private func clearSelection() {
        selectedCharity = nil
        UserDefaults.standard.removeObject(forKey: "selectedCharityId")
    }
}

// MARK: - Current Charity Card
struct CurrentCharityCard: View {
    let charity: Charity
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Current Selection")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                    .font(.system(size: 20))
            }
            
            HStack(spacing: DesignSystem.Spacing.md) {
                if let name = charity.logoAssetName, let uiImage = UIImage(named: name) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(charity.emoji)
                        .font(.system(size: 40))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(charity.name)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(charity.description)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
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

// MARK: - Charity Card
struct CharityCard: View {
    let charity: Charity
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Logo or Emoji Indicator
                if let name = charity.logoAssetName, let uiImage = UIImage(named: name) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ZStack {
                        Circle()
                            .fill(charity.color.opacity(0.2))
                            .frame(width: 60, height: 60)
                        Text(charity.emoji)
                            .font(.system(size: 28))
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(charity.name)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(charity.description)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                        .font(.system(size: 24))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .font(.system(size: 24))
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(isSelected ? charity.color.opacity(0.05) : DesignSystem.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(isSelected ? charity.color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}

// MARK: - Info Card
struct InfoCard: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: 20))
                
                Text("How It Works")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                InfoRow(
                    icon: "1.circle.fill",
                    text: "When you exceed your daily app limits, you can pay to unlock more time"
                )
                
                InfoRow(
                    icon: "2.circle.fill",
                    text: "A percentage of your unlock fee goes directly to your chosen charity"
                )
                
                InfoRow(
                    icon: "3.circle.fill",
                    text: "You can change your charity selection anytime in Settings"
                )
                
                InfoRow(
                    icon: "4.circle.fill",
                    text: "View your total donations and impact in your Profile"
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.primary)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            Text(text)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    SetupCharitySelectionView()
} 
