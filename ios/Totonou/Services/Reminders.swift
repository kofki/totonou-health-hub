import Foundation
import UserNotifications

/// One notification to show at one time.
struct ReminderItem: Sendable {
    let id: String
    let title: String
    let body: String
    let at: Date
}

/// Quest reminders. Behind a protocol so previews and tests never touch the
/// real notification centre.
protocol Reminders: Sendable {
    func requestPermission() async -> Bool
    /// Replaces everything that was scheduled before.
    func schedule(_ items: [ReminderItem]) async
}

struct NoReminders: Reminders {
    func requestPermission() async -> Bool { false }
    func schedule(_ items: [ReminderItem]) async {}
}

/// Local notifications: scheduled on the phone, no server involved.
struct LocalReminders: Reminders {
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(_ items: [ReminderItem]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        // iOS keeps at most 64 pending notifications per app.
        for item in items.sorted(by: { $0.at < $1.at }).prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.at)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}

/// Without this, iOS hides notifications while the app is open.
final class ReminderPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
