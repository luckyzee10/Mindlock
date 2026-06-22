import SwiftUI
import FamilyControls
import ManagedSettings

struct BlockListAppRow: View {
    let applicationToken: ApplicationToken

    var body: some View {
        HStack {
            Label(applicationToken)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "timer")
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .opacity(0.6)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}
