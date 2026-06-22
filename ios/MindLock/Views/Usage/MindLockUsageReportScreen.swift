import SwiftUI
#if canImport(DeviceActivity) && canImport(_DeviceActivity_SwiftUI)
import DeviceActivity
import _DeviceActivity_SwiftUI
#endif

struct MindLockUsageReportScreen: View {
    #if canImport(DeviceActivity) && canImport(_DeviceActivity_SwiftUI)
    private let reportContext = DeviceActivityReport.Context("MindLockUsage")
    #endif

    var body: some View {
        VStack {
            reportSection
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var reportSection: some View {
        #if canImport(DeviceActivity) && canImport(_DeviceActivity_SwiftUI)
        DeviceActivityReport(reportContext, filter: DeviceActivityFilter())
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05))
            )
        #else
        UnsupportedUsageReportView()
        #endif
    }
}

private struct UnsupportedUsageReportView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Usage analytics are available on-device.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Build and run on an iPhone or iPad enrolled in Screen Time to review your MindLock usage.")
                .font(DesignSystem.Typography.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(DesignSystem.Colors.surfaceSecondary)
        .cornerRadius(20)
    }
}
