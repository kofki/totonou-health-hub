import SwiftData
import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 18 · Objective row                   (SwiftUI layout, ForEach, state)
//
// An objective is a count to hit per day, per week, or over a whole arc:
// "Strength sessions, 4 a week". Quests are its steps: each one linked to it
// that you finish adds one. The arc screen lists every objective with this row,
// and right now the row is one plain line of text. Make it the place where you
// see, at a glance, how far each target has come.
//
// Build it
//   1. Title on the left, `objective.label()` ("2 of 4 this week") on the right
//      in `Font.number`.
//   2. Under it, one pip per unit of the target: filled (Ink.ai) for each done,
//      outlined for the rest. With a target above 10, use `ProgressLine` with
//      `objective.fraction()` instead, so 30 pips do not squeeze the row.
//   3. When it is met (`objective.isMet()`), show a `.check` glyph next to the
//      count and tint the pips with the jade of rank D (`Rank.d.tint`).
//   4. Show `objective.detail` as a caption when it is not empty.
//   5. Tap the row to unfold its steps: the quests linked to it in this period,
//      each with a tick or an empty box. `objective.quests` holds them all;
//      keep the ones inside `objective.period.window(containing: .now, arc:)`.
//   6. Accessibility: one label for the row, "Strength sessions, 2 of 4 this week".
//
// You will practise: HStack/VStack layout, ForEach over a range, conditional
// styling, @State for the unfolded part, filtering a relationship.
// Read first: `ArcRow` and `CheckBox` in Features/Arcs/ArcsView.swift,
// `ProgressLine` in App/Components.swift, `Objective` in Models/Models.swift.
// Check it in the #Preview below, then open an arc on the Arcs tab.
// ─────────────────────────────────────────────────────────────────────────────

struct ObjectiveRow: View {
    let objective: Objective

    var body: some View {
        // TODO(you): replace this with the row described above.
        HStack {
            Text(objective.title).font(.text(17))
            Spacer()
            Text(objective.label()).caption()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    // An in-memory store: nothing here is saved, and it never reaches the app.
    let container = try! ModelContainer(for: Arc.self, Quest.self, Objective.self, Boss.self, BossTask.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let arc = Arc(title: "Healthy body", kanji: "道", manifesto: "", goals: [], startDate: .now,
                  endDate: .distantFuture, kind: .objective)
    let sessions = Objective(title: "Strength sessions", period: .week, target: 4,
                             detail: "45 min, compound lifts first")
    container.mainContext.insert(arc)
    container.mainContext.insert(sessions)
    arc.objectives.append(sessions)
    for offset in 0..<2 {
        let quest = Quest(title: "Strength session", stat: .strength, rank: .c,
                          scheduledAt: .now.addingTimeInterval(Double(-offset) * 3_600), arc: arc).linked(to: sessions)
        quest.completedAt = quest.scheduledAt
        container.mainContext.insert(quest)
    }
    return ObjectiveRow(objective: sessions)
        .padding()
        .background(Ink.raised)
        .foregroundStyle(Ink.washi)
        .modelContainer(container)
}
