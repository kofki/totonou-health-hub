import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 17 · 終 · Finished arc row              (computed properties, dates)
//
// The Arcs tab lists the arcs that are over under "Finished". Each row is only
// a grey title, so an arc you ran for the full 90 days looks the same as one
// you dropped after a week. Make the row tell the story of the arc.
//
// What it should show
//   • The title, as now.
//   • How it ended: "Completed" or "Ended early". `arc.isCompleted` already
//     knows the rule; read it in Models.swift and say it back in your own words.
//   • What kind it was: `arc.kind.name` and `arc.kind.glyph`.
//   • How long it lasted. `arc.dayLabel()` gives "Day 12 of 90" for a season
//     and "Day 40" for an objective; write your own wording from `arc.day(on:)`
//     and `arc.closedAt` if you want "12 of 90 days". An objective has no
//     `totalDays` worth showing: its end date is `.distantFuture`.
//   • The dates it ran, e.g. "Sep 1 – Nov 24". Look at how `DayTally.label`
//     in Services/Coach.swift formats a date, and at `Date.formatted(_:)`.
//   • What you got done: goals, quests and boss tasks. `arc.progress()` has
//     the counts.
//
// Steps
//   1. Add private computed properties for each piece of text (`ending`,
//      `length`, `dates`, `done`), so `body` stays short.
//   2. Lay them out. A SystemPanel with the title on top and the facts below
//      as captions reads well; ArcRow in Features/Arcs/ArcsView.swift is the
//      card for an active arc, so look there first.
//   3. Give a completed arc a ClearStamp (App/Components.swift) and leave an
//      arc that was ended early without one.
//   4. Open the preview at the bottom and add a second arc to it that was ended
//      early, so you can see both kinds side by side.
//
// Rules: only the colours in `Ink`, icons only from `Glyph`, short English text.
//
// You will practise: computed properties, optionals (`endedAt`), formatting
// dates, min(_:_:), composing a view from the app's own components, previews.
//
// How to check: start an arc in the app, open it, end it, and look at the
// "Finished" section of the Arcs tab.
// ─────────────────────────────────────────────────────────────────────────────

struct FinishedArcRow: View {
    let arc: Arc

    var body: some View {
        // TODO(you): replace this line with the full row.
        Text(arc.title)
            .font(.text(17))
            .foregroundStyle(Ink.mute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        Backdrop()
        FinishedArcRow(arc: Arc(title: "Winter Arc", kanji: "", manifesto: "", goals: [],
                                startDate: .now.addingTimeInterval(-90 * 86_400), endDate: .now))
            .padding(20)
    }
    .foregroundStyle(Ink.washi)
}
