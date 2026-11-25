import SwiftData
import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 11 · 畳む · Collapse the Done list            (@State, animation)
//
// Finished quests sit in this section at the bottom of Today. By the evening it
// is the longest thing on the screen. Make the header a button that folds the
// list away, and remember the choice.
//
// Steps
//   1. Add `@State private var isOpen = true` and show the rows only when it is
//      true.
//   2. Make the header row a Button that flips it. Wrap the flip in
//      withAnimation so the rows slide rather than jump.
//   3. Add a chevron (GlyphIcon(.chevron)) that points right when closed and
//      down when open: .rotationEffect(.degrees(isOpen ? 90 : 0)).
//   4. Swap @State for @AppStorage("doneSectionOpen") so it survives a relaunch.
//      Notice that nothing else in the view has to change.
//
// You will practise: @State vs @AppStorage, conditional views, withAnimation,
// and why a Button is better than .onTapGesture for accessibility.
//
// How to check: finish two quests on Today, fold the section, relaunch the app.
// ─────────────────────────────────────────────────────────────────────────────

struct DoneSection<Row: View>: View {
    let quests: [Quest]
    @ViewBuilder var row: (Quest) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // TODO(you): make this header fold the list.
            HStack(spacing: 10) {
                Text("Done").font(.text(22, weight: .bold))
                Text("\(quests.count)").font(.number(17)).foregroundStyle(Ink.mute)
                Spacer()
            }
            ForEach(quests) { quest in
                row(quest)
            }
        }
    }
}
