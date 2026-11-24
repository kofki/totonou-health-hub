import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 1 · 連続 · Streak                                    (Swift basics)
//
// The Today screen shows your streak. Right now it is always 0, because this
// function is yours to write.
//
// Rules
//   • A "completion day" is a day on which at least one quest was finished.
//   • The streak is the number of consecutive completion days, counting back
//     from today.
//   • If nothing is finished today yet, the streak is still alive: count back
//     from yesterday instead. (A streak only dies once a whole day is missed.)
//   • The input can contain the same day more than once, at any time of day,
//     in any order.
//
// You will practise: Set, Calendar.startOfDay(for:), calendar.date(byAdding:),
// while loops, guard.
//
// Check your work:  cd ios/TotonouCore && swift test --filter Streak
// ─────────────────────────────────────────────────────────────────────────────

public enum StreakCalculator {
    public static func currentStreak(
        completionDays: [Date],
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        // TODO(you): replace this line.
        return 0
    }
}
