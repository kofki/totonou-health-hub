import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 20 · Step progress                         (ForEach over a range, layout)
//
// A quest can have steps (sub-quests). Under its title, Today shows how many
// are done. Right now that is plain text, "1/3 steps". Make it a small row of
// pips you can read at a glance.
//
// Build it
//   1. One small circle (about 7 points) per step, in an HStack with spacing 4.
//   2. Done steps are filled with `Ink.ai`; open ones are only an outline in `Ink.mute`.
//   3. After the pips, the count as text in `Font.number`: "1/3".
//   4. With more than 8 steps, show `ProgressLine(value:)` 40 points wide
//      instead of the pips, so the row stays short.
//   5. Accessibility: one label, "1 of 3 steps done".
//
// You will practise: ForEach over `0..<total`, conditional fill and stroke,
// small fixed sizes, accessibility labels.
// Read first: `QuestRow` in Features/Today/TodayView.swift, `ProgressLine` in
// App/Components.swift. Check it in the #Preview, then add steps to a quest.
// ─────────────────────────────────────────────────────────────────────────────

struct StepProgress: View {
    let done: Int
    let total: Int

    var body: some View {
        // TODO(you): replace this with the pips described above.
        Text("\(done)/\(total) steps")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StepProgress(done: 0, total: 3)
        StepProgress(done: 2, total: 3)
        StepProgress(done: 5, total: 12)
    }
    .padding()
    .background(Ink.raised)
    .foregroundStyle(Ink.washi)
}
