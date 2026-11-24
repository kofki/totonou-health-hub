import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 14 · 忙 · Busy-block filter                     (enums, boolean logic)
//
// Totonou moves a quest when it lands on top of something in your calendar.
// But not every event should block a quest: a birthday is all-day, a "focus
// time" hold can be marked free, and you will not go to a meeting you declined.
// Right now every event counts as busy, so quests move more than they should.
//
// Rules — an event is busy unless any of these is true:
//   • it is all-day
//   • its availability is `.free`
//   • you declined it
// Tentative and unavailable events are busy.
//
// You will practise: switch over an enum, combining conditions, early return.
//
// Check your work:  cd ios/TotonouCore && swift test --filter BusyFilter
// ─────────────────────────────────────────────────────────────────────────────

public enum BusyFilter {
    public static func isBusy(_ event: CalendarEventInfo) -> Bool {
        // TODO(you): replace this line.
        return true
    }
}
