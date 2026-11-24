import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 5 · 覚醒 · Level up                              (animation)
//
// This overlay appears when QuestEngine.levelUp is set. It works, but it just
// pops in. Levelling up is the biggest moment in the app — make it feel like one.
//
// Ideas, roughly in order of difficulty
//   1. Fade and scale the whole overlay in. (.transition needs an animated state
//      change to run — find where RootView shows this view.)
//   2. Stagger it: label first, then the number, then the line under it.
//      One @State per stage, flipped in .onAppear with withAnimation(.delay(...)).
//   3. Count the number up from level − 1. Look up .contentTransition(.numericText()).
//   4. Draw the EnsoRing around the number from 0 to 1.
//   5. A haptic: .sensoryFeedback(.success, trigger:).
//
// Keep it under about 1.5 seconds and keep it quiet — one accent colour, no
// confetti. Respect @Environment(\.accessibilityReduceMotion).
//
// To trigger it quickly: a new player needs only 100 XP for level 2, so start an
// arc and finish a few quests. The #Preview below shows it without playing.
// ─────────────────────────────────────────────────────────────────────────────

struct LevelUpOverlay: View {
    let level: Int
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Ink.deep.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("レベルアップ").caption(Ink.ai, size: 18)
                Text("\(level)")
                    .font(.number(120, weight: .bold))
                    .shadow(color: Ink.ai.opacity(0.7), radius: 24)
                Rectangle().fill(Ink.ai).frame(width: 120, height: 1)
                Text("Tap to continue").caption()
                    .padding(.top, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
    }
}

#Preview {
    LevelUpOverlay(level: 8) {}
        .foregroundStyle(Ink.washi)
}
