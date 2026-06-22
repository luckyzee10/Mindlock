import SwiftUI

struct SetupTooltip: View {
    enum ArrowDirection {
        case up
        case down
    }

    let text: String
    var actionTitle: String = "Got it"
    var arrow: ArrowDirection = .down
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if arrow == .up { arrowView }
            bubble
            if arrow == .down { arrowView }
        }
        .transition(.move(edge: arrow == .down ? .top : .bottom).combined(with: .opacity))
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(text)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle) {
                onDismiss()
            }
            .font(DesignSystem.Typography.caption.bold())
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(Color.white.opacity(0.2))
            .cornerRadius(DesignSystem.CornerRadius.sm)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.primary)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .shadow(radius: 4)
    }

    private var arrowView: some View {
        Image(systemName: arrow == .down ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.bottom, arrow == .down ? 0 : DesignSystem.Spacing.xs)
            .padding(.top, arrow == .up ? 0 : DesignSystem.Spacing.xs)
    }
}
