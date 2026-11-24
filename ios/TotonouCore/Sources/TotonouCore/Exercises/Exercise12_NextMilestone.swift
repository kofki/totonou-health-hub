import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 12 · 次 · Next milestone                          (arrays, optionals)
//
// The Rewards screen shows "Next chest: 14-day streak · 8/14". To draw that it
// needs the next streak milestone and how many days are left until it. Until
// you write this, the function returns nil and the screen simply hides the bar.
//
// Rules
//   • The milestones are `StreakMilestones.all` (3, 7, 14, 30, 60, 100 days).
//   • The next milestone is the first one with more days than the current streak.
//     A streak of exactly 7 has already opened the 7-day chest, so the next is 14.
//   • `daysLeft` is milestone days minus the streak.
//   • Past the last milestone there is no next one: return nil.
//   • A negative streak counts as 0.
//
// You will practise: first(where:), optionals, returning a tuple, max(_:_:).
//
// Check your work:  cd ios/TotonouCore && swift test --filter NextMilestone
// ─────────────────────────────────────────────────────────────────────────────

public enum NextMilestone {
    public static func after(streak: Int) -> (milestone: StreakMilestone, daysLeft: Int)? {
        // TODO(you): replace this line.
        return nil
    }
}
