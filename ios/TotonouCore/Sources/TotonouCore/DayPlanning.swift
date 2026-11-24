import Foundation

/// A calendar event reduced to what the game needs. The app fills it from
/// EventKit; keeping it a plain struct here means the rules can be tested
/// without calendar access.
public struct CalendarEventInfo: Equatable, Sendable, Identifiable {
    public enum Availability: String, Sendable { case busy, free, tentative, unavailable }

    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let availability: Availability
    public let isDeclined: Bool
    /// The calendar's own name, such as "Work" or the Google account.
    public let calendarName: String

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
                availability: Availability = .busy, isDeclined: Bool = false, calendarName: String = "") {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.availability = availability
        self.isDeclined = isDeclined
        self.calendarName = calendarName
    }

    public var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }
}

public enum DayPlanner {
    /// The first start time at or after `start` where a quest of `minutes` fits
    /// without overlapping a busy block. Returns `start` when nothing is in the way,
    /// and `nil` if the quest would no longer fit before `dayEnd`.
    public static func firstFreeStart(at start: Date, minutes: Int, busy: [DateInterval], dayEnd: Date) -> Date? {
        let length = TimeInterval(minutes * 60)
        var candidate = start
        // Sorting by start means one pass is enough: each overlap pushes the
        // candidate past that block, and later blocks start later.
        for block in busy.sorted(by: { $0.start < $1.start }) {
            let slot = DateInterval(start: candidate, duration: length)
            if block.end > slot.start && block.start < slot.end {
                candidate = max(candidate, block.end)
            }
        }
        return candidate.addingTimeInterval(length) <= dayEnd ? candidate : nil
    }
}
