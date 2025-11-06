import Foundation
import ManagedSettingsUI
import ManagedSettings
import UIKit
import FamilyControls

// Uses App Group to persist simple daily counts per app
private enum ShieldStatsKeys {
    static func countKey(_ bundle: String) -> String { "shield.blocks.\(bundle).count" }
    static func dateKey(_ bundle: String) -> String { "shield.blocks.\(bundle).date" }
}

final class MindLockShieldDataSource: ShieldConfigurationDataSource {
    // Configure the system shield shown when an app is blocked
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? application.bundleIdentifier ?? "This app"
        let bundle = application.bundleIdentifier ?? "unknown.bundle"

        // Increment "blocked times today" counter whenever the shield is requested
        let defaults = UserDefaults(suiteName: SharedSettings.appGroupIdentifier)
        let today = Calendar.current.startOfDay(for: Date())
        let last = defaults?.object(forKey: ShieldStatsKeys.dateKey(bundle)) as? Date
        if last == nil || !Calendar.current.isDate(last!, inSameDayAs: today) {
            defaults?.set(today, forKey: ShieldStatsKeys.dateKey(bundle))
            defaults?.set(0, forKey: ShieldStatsKeys.countKey(bundle))
        }
        let current = (defaults?.integer(forKey: ShieldStatsKeys.countKey(bundle)) ?? 0) + 1
        defaults?.set(current, forKey: ShieldStatsKeys.countKey(bundle))
        let times = current

        // Title + body copy (Opal-inspired)
        let title = ShieldConfiguration.Label(text: "1,500 Hours Saved", color: .white)
        let lines = [
            "…and counting, from all MindLock customers globally.",
            "\(appName) was blocked during your session.",
            "You're saving time, too.",
            "Manage blocking by opening the MindLock app.",
            "💎 \(appName) Blocked: \(times)x Today"
        ]
        let subtitle = ShieldConfiguration.Label(text: lines.joined(separator: "\n\n"), color: UIColor(white: 1.0, alpha: 0.85))

        // Single white button
        let primary = ShieldConfiguration.Label(text: "Close", color: .black)

        // Optional brand icon from the extension bundle
        let icon = UIImage(named: "ShieldIcon")

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: .black,
            icon: icon,
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: primary,
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }
}
