import Foundation
import SwiftUI
import TotonouCore
#if canImport(AlarmKit)
import AlarmKit
#endif

// Real alarms: they ring through silent mode and Focus, show on the Lock
// Screen and the watch, and offer Done and Snooze. AlarmKit arrived in iOS 26;
// on older systems `NoAlarms` is used and quest reminders stay notifications.
//
// iOS gives no app access to the Clock app's own alarms, so Totonou can only
// manage the alarms it creates itself.

@MainActor
protocol QuestAlarms: AnyObject {
    var isSupported: Bool { get }
    func requestPermission() async -> Bool
    /// One alarm at a fixed time. Returns its id, or nil if it could not be set.
    func schedule(title: String, at date: Date) async -> String?
    /// An alarm that rings every day at the same time.
    func scheduleDaily(title: String, hour: Int, minute: Int) async -> String?
    func cancel(id: String)
}

enum Alarms {
    @MainActor
    static func make() -> any QuestAlarms {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return AlarmKitAlarms() }
        #endif
        return NoAlarms()
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
@MainActor
final class AlarmKitAlarms: QuestAlarms {
    private let manager = AlarmManager.shared
    var isSupported: Bool { true }

    func requestPermission() async -> Bool {
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        default: return (try? await manager.requestAuthorization()) == .authorized
        }
    }

    func schedule(title: String, at date: Date) async -> String? {
        await schedule(title: title, schedule: .fixed(date))
    }

    func scheduleDaily(title: String, hour: Int, minute: Int) async -> String? {
        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let everyDay: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        return await schedule(title: title, schedule: .relative(.init(time: time, repeats: .weekly(everyDay))))
    }

    func cancel(id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        try? manager.cancel(id: uuid)
    }

    private func schedule(title: String, schedule: Alarm.Schedule) async -> String? {
        guard await requestPermission() else { return nil }
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource("\(title)"),
            stopButton: AlarmButton(text: "Done", textColor: Ink.washi, systemImageName: "checkmark"),
            secondaryButton: AlarmButton(text: "Snooze", textColor: Ink.washi, systemImageName: "zzz"),
            // .countdown makes Snooze restart a countdown of `postAlert` seconds.
            secondaryButtonBehavior: .countdown
        )
        let presentation = AlarmPresentation(alert: alert, countdown: .init(title: LocalizedStringResource("\(title) · snoozed")))
        let attributes = AlarmAttributes<QuestAlarmData>(presentation: presentation, metadata: QuestAlarmData(title: title), tintColor: Ink.ai)
        let configuration = AlarmManager.AlarmConfiguration<QuestAlarmData>(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60),
            schedule: schedule,
            attributes: attributes
        )
        let id = UUID()
        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
            return id.uuidString
        } catch {
            return nil
        }
    }
}
#endif

/// No alarms on this system. Also used in previews and tests.
@MainActor
final class NoAlarms: QuestAlarms {
    var isSupported: Bool { false }
    func requestPermission() async -> Bool { false }
    func schedule(title: String, at date: Date) async -> String? { nil }
    func scheduleDaily(title: String, hour: Int, minute: Int) async -> String? { nil }
    func cancel(id: String) {}
}
