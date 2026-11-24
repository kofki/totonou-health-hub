import EventKit
import Foundation
import TotonouCore

// Your calendar and reminders. Like every outside system, it sits behind a
// protocol so previews and tests can use `NoDaySource`.
//
// Google Calendar arrives through iOS itself: add the Google account under
// Settings → Calendar → Accounts and its calendars appear in EventKit with
// everything else. That avoids Google sign-in, and its login that expires
// every 7 days while a Google app is in testing.

/// A reminder that is due, reduced to what a quest needs.
struct ReminderInfo: Sendable, Equatable {
    let id: String
    let title: String
    let due: Date?
}

@MainActor
protocol DaySource: AnyObject {
    var hasCalendarAccess: Bool { get }
    var hasRemindersAccess: Bool { get }
    func requestCalendarAccess() async -> Bool
    func requestRemindersAccess() async -> Bool
    func events(on day: Date) -> [CalendarEventInfo]
    /// Unfinished reminders due by the end of `day`, overdue ones included.
    func remindersDue(by day: Date) async -> [ReminderInfo]
    /// nil when the reminder no longer exists.
    func isReminderCompleted(id: String) -> Bool?
    func completeReminder(id: String)
}

extension DaySource {
    /// The events that should push a quest out of the way.
    func busyBlocks(on day: Date) -> [DateInterval] {
        events(on: day).filter(BusyFilter.isBusy).map(\.interval)
    }
}

@MainActor
final class EventKitDaySource: DaySource {
    static let shared = EventKitDaySource()

    // One store for the whole app: creating EKEventStore is slow.
    private let store = EKEventStore()

    // iOS 17 split calendar access into "write only" and "full". Reading
    // events needs full access, so that is the only level checked here.
    var hasCalendarAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var hasRemindersAccess: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    func requestCalendarAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func requestRemindersAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    func events(on day: Date) -> [CalendarEventInfo] {
        guard hasCalendarAccess else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEventInfo(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Busy",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                availability: Self.availability(event.availability),
                isDeclined: event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined,
                calendarName: event.calendar?.title ?? ""
            )
        }
        .sorted { $0.start < $1.start }
    }

    func remindersDue(by day: Date) async -> [ReminderInfo] {
        guard hasRemindersAccess else { return [] }
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        // EventKit still reports reminders through a completion handler. A
        // continuation turns that into a value `await` can wait for. EKReminder
        // is not Sendable, so it is turned into a plain struct before leaving.
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let infos = (reminders ?? []).map {
                    ReminderInfo(id: $0.calendarItemIdentifier, title: $0.title ?? "Reminder",
                                 due: $0.dueDateComponents.flatMap { Calendar.current.date(from: $0) })
                }
                continuation.resume(returning: infos)
            }
        }
    }

    func isReminderCompleted(id: String) -> Bool? {
        (store.calendarItem(withIdentifier: id) as? EKReminder)?.isCompleted
    }

    func completeReminder(id: String) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder, !reminder.isCompleted else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
    }

    private static func availability(_ value: EKEventAvailability) -> CalendarEventInfo.Availability {
        switch value {
        case .free: .free
        case .tentative: .tentative
        case .unavailable: .unavailable
        default: .busy
        }
    }
}

/// Nothing connected. For previews and tests.
@MainActor
final class NoDaySource: DaySource {
    var hasCalendarAccess: Bool { false }
    var hasRemindersAccess: Bool { false }
    func requestCalendarAccess() async -> Bool { false }
    func requestRemindersAccess() async -> Bool { false }
    func events(on day: Date) -> [CalendarEventInfo] { [] }
    func remindersDue(by day: Date) async -> [ReminderInfo] { [] }
    func isReminderCompleted(id: String) -> Bool? { nil }
    func completeReminder(id: String) {}
}
