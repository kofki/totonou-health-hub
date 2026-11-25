import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 16 · 合 · Merge the daily plans            (generics, Set, sorting)
//
// Several arcs can run at once, and each has its own list of daily quests. The
// Arcs tab shows them together under "Every day", and reminders and the wake
// alarm are planned from the same combined list. Right now the lists are just
// glued end to end: arc by arc instead of in time order, and if two arcs both
// say "Read 20 min" it shows up twice.
//
// Rules
//   • The result holds every slot from every plan, earliest time of day first
//     (compare hour, then minute).
//   • Two slots with the same title are the same quest: keep only the earliest.
//     Titles match without caring about capitals or spaces at the ends, so
//     "Read 20 min" and " read 20 MIN " are the same.
//   • Two slots at the same time keep the order they came in (first plan first).
//   • No plans, or only empty plans, gives an empty list.
//
// Steps
//   1. Flatten the plans into one array (it is already done below).
//   2. Sort it by time. A tuple compares left to right, so
//      `(a.hour, a.minute) < (b.hour, b.minute)` is all you need. Check whether
//      `sorted(by:)` promises to keep equal elements in order; if it does not,
//      sort on something that makes every element different.
//   3. Walk the sorted array and keep a slot only if its title is new. A
//      `Set<String>` remembers what you have seen; `insert` tells you whether
//      the value was already there.
//
// `Slot` is a generic placeholder: the function works for any type that has a
// title, an hour and a minute (`DailySlot`). The app passes its `QuestIdea`;
// the tests pass a tiny struct of their own.
//
// You will practise: generic functions with a protocol constraint, tuples,
// sorted(by:), Set, string clean-up (lowercased, trimmingCharacters).
//
// Check your work:  cd ios/TotonouCore && swift test --filter PlanMerger
// Then start two arcs in the app and look at "Every day" on the Arcs tab.
// ─────────────────────────────────────────────────────────────────────────────

/// Something that happens at a fixed time every day.
public protocol DailySlot {
    var title: String { get }
    var hour: Int { get }
    var minute: Int { get }
}

public enum PlanMerger {
    public static func merged<Slot: DailySlot>(_ plans: [[Slot]]) -> [Slot] {
        // TODO(you): put these in time order and drop repeated titles.
        return plans.flatMap { $0 }
    }
}
