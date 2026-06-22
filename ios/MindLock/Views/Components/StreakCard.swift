import SwiftUI

struct StreakCard: View {
    let days: Int

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(spacing: 4) {
                Text("Streak")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Image(systemName: "flame.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(fireColor)
                .shadow(color: fireColor.opacity(0.35), radius: days == 0 ? 0 : 6)

            VStack(spacing: 8) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let ratio = min(Double(days), 28.0) / 28.0
                    let trackColor = DesignSystem.Colors.textTertiary.opacity(days == 0 ? 0.35 : 0.22)
                    let separatorColor = DesignSystem.Colors.textTertiary.opacity(days == 0 ? 0.35 : 0.25)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(trackColor)
                            .frame(height: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(DesignSystem.Colors.textTertiary.opacity(0.12), lineWidth: 1)
                            )

                        RoundedRectangle(cornerRadius: 4)
                            .fill(barGradient)
                            .frame(width: width * ratio, height: 8)

                        HStack(spacing: 0) {
                            ForEach(1..<5, id: \.self) { _ in
                                Spacer()
                                Rectangle()
                                    .fill(separatorColor)
                                    .frame(width: 1, height: 8)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(height: 8)

                Text("\(days) \(days == 1 ? "day" : "days")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("Impact multiplier ×\(SharedSettings.impactMultiplier(forStreak: days))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if days >= 28 {
                    Text("You’ve maxed out this month’s boost.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var subtitle: String {
        days == 0 ? "Start your streak" : "Keep going to amplify donations"
    }

    private var fireColor: Color {
        switch days {
        case 0:
            return DesignSystem.Colors.textTertiary
        case 1..<3:
            return .yellow.opacity(0.8)
        case 3..<5:
            return Color.orange.opacity(0.8)
        case 5..<7:
            return Color.red.opacity(0.85)
        default:
            return DesignSystem.Colors.primary
        }
    }

    private var barGradient: LinearGradient {
        LinearGradient(colors: [.yellow, .red], startPoint: .leading, endPoint: .trailing)
    }
}

#if DEBUG
struct StreakCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            StreakCard(days: 0)
            StreakCard(days: 3)
            StreakCard(days: 12)
        }
        .padding()
        .background(DesignSystem.Colors.background)
    }
}
#endif
