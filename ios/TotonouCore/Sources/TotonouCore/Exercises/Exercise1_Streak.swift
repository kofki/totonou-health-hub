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
//
// Status: handed over to Claude on 2026-11-24 (owner's choice). Solved below.
// Days saved by a streak freeze are passed in with the completion days, so
// this function does not need to know freezes exist.
// ─────────────────────────────────────────────────────────────────────────────

public enum StreakCalculator {
    public static func currentStreak(
        completionDays: [Date],
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        // A Set of start-of-day dates makes duplicates and order irrelevant.
        let days = Set(completionDays.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            // Today is not over yet: the streak is alive if yesterday counted.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
