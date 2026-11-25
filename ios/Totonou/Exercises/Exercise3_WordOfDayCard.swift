import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 3 · 言葉 · Word of the day                    (SwiftUI layout)
//
// This card sits at the bottom of the Status screen. It already receives the
// right word — it just does not show it yet. Build the view.
//
// It should show
//   • the word itself, large                   →  word.word       e.g. 整う
//   • its reading, small, above or beside it   →  word.reading    e.g. ととのう
//   • the meaning                              →  word.meaning
//   • a short title so it is clear what this is ("Word of the day")
//
// Use what already exists: `SystemPanel`, `Font.text`, `Font.number`,
// `.caption()`, the `Ink` colours. Read App/Components.swift first and copy
// the rhythm of the other screens (spacing 6–18, nothing centred, no new colours).
//
// You will practise: VStack/HStack, alignment, spacing, modifiers order,
// and #Preview — open the canvas (⌥⌘↩) and iterate without running the app.
//
// Stretch: tap the card to flip between the word and its reading with
// @State and withAnimation.
// ─────────────────────────────────────────────────────────────────────────────

struct WordOfDayCard: View {
    let word: JapaneseWord

    var body: some View {
        // TODO(you): replace this placeholder with the real card.
        SystemPanel(tint: Ink.mute) {
            Text("Exercise 3: the word of the day goes here").caption()
        }
    }
}

#Preview {
    WordOfDayCard(word: WordBook.all[0])
        .padding(22)
        .frame(maxHeight: .infinity)
        .background(Ink.sumi)
        .foregroundStyle(Ink.washi)
}
