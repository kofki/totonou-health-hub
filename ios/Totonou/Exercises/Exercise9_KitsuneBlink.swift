import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 9 · 瞬 · Make the coach blink                    (animation)
//
// The fox mask at the top of the Coach screen stares without blinking. Bring it
// to life: a quick blink every few seconds.
//
// `KitsuneMask(eyeOpen:)` already knows how to draw its eyes anywhere between
// 1 (open) and 0 (shut). Your job is to drive that number over time.
//
// Rules
//   • A blink is fast: about 0.1 s to close, 0.15 s to open. Then a long pause.
//   • No timers (`Timer`, `DispatchQueue`). SwiftUI has better tools.
//   • When Reduce Motion is on, the eyes stay open.
//
// Two ways to do it — pick one, then try the other
//   A. `.phaseAnimator([...])`: list the phases (open, shut, open-and-wait) and
//      give each phase its own animation. Finished examples: the hunter's aura
//      and the oni's eyes in App/Characters.swift.
//   B. `@State` plus `.task { while !Task.isCancelled { ... } }` with
//      `try? await Task.sleep(for:)` and `withAnimation`.
//
// You will practise: driving a view from a changing value, phaseAnimator or
// structured concurrency, and reading @Environment(\.accessibilityReduceMotion).
//
// How to check: open the canvas (⌥⌘↩) on this file and watch for ten seconds.
// Stretch: make the pause a little different each time so it feels alive.
// ─────────────────────────────────────────────────────────────────────────────

struct CoachKitsune: View {
    var body: some View {
        // TODO(you): animate eyeOpen.
        KitsuneMask(eyeOpen: 1)
    }
}

#Preview {
    CoachKitsune()
        .frame(width: 220)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.sumi)
}
