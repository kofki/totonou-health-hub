import SwiftData
import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 4 · 記録 · Quest log                          (SwiftData queries)
//
// Opened from the "QUEST LOG" button on the Status screen. Show every quest that
// has been completed, newest first, grouped by day.
//
// Steps
//   1. Add a @Query that fetches only completed quests, sorted by completedAt
//      descending. You need a #Predicate — look at how Bootstrap.rollDailyQuests
//      (Services/QuestPlanner.swift) builds one, and at how TodayView declares its @Query.
//   2. Group the results by day. Dictionary(grouping:by:) with
//      Calendar.current.startOfDay(for:) is one way. Dictionaries are unordered,
//      so sort the keys before you loop.
//   3. For each day: a SectionHeader (try date.dayTitle) and one row per quest
//      with its rank, title, completion time and XP.
//   4. Show something calm when the log is empty.
//
// You will practise: @Query, #Predicate, optionals inside predicates,
// Dictionary(grouping:), ForEach over non-Identifiable data (id: \.self).
//
// Stretch: total XP per day in the section header; a filter by Stat.
// ─────────────────────────────────────────────────────────────────────────────

struct QuestHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    // TODO(you): step 1 — the @Query goes here.

    var body: some View {
        ZStack {
            Backdrop()
            Screen {
                HStack {
                    Text("Quest log").font(.text(28, weight: .bold))
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(.plain).caption(size: 16)
                }

                // TODO(you): steps 2–4 — replace this placeholder.
                SystemPanel(tint: Ink.mute) {
                    Text("Exercise 4: your completed quests go here").caption()
                }
            }
        }
        .foregroundStyle(Ink.washi)
        .preferredColorScheme(.dark)
    }
}
