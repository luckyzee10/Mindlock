import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() { super.init() }

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Notifications

    func postFreeUnlockNotification(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(minutes)-minute break unlocked"
        content.body = "Every limited app is open for \(minutes) minutes. Use the time intentionally."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func postDayPassNotification(minutesUntilMidnight: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Day pass unlocked"
        if minutesUntilMidnight >= 60 {
            let hours = Double(minutesUntilMidnight) / 60
            content.body = String(format: "All limited apps are available for the rest of today (~%.1f hours). Make it count.", hours)
        } else {
            content.body = "All limited apps stay open for the rest of today. Stay intentional."
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func postSettingsUpdatedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time limit settings updated"
        content.body = "Your changes are now live. Stay mindful — you’ve got this."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func scheduleSettingsUpdatedAtMidnightIfNeeded() {
        // Schedule a best-effort notification at next midnight
        var date = Calendar.current.date(byAdding: .day, value: 0, to: Date()) ?? Date()
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let nextMidnight = Calendar.current.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: 0, minute: 0)) ?? Date()
        let triggerDate = nextMidnight > Date() ? nextMidnight : Calendar.current.date(byAdding: .day, value: 1, to: nextMidnight) ?? Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "Time limit settings updated"
        content.body = "Your pending changes have been applied. Keep the streak going."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "settings-updated-midnight", content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.add(request, withCompletionHandler: nil)
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// Convenience to present alerts from anywhere
extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topMostViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
}
