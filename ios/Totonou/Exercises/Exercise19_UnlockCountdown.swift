import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 19 · Unlock countdown                        (TimelineView, Date math)
//
// When you spend earned minutes, the Screen Time lock opens your apps until a
// set time. The setup screen says "Open until 14:30" and never changes. Make it
// count down, so you can see how much is left at a glance.
//
// Build it
//   1. Wrap the content in `TimelineView(.periodic(from: .now, by: 1))`, which
//      redraws every second and hands you `context.date`.
//   2. Work out the seconds left: `until.timeIntervalSince(context.date)`.
//      Below zero, show "Locked again" instead.
//   3. Show minutes and seconds as "12:07 left" in `Font.number`. Hint: integer
//      division and `%` on the whole seconds, and `String(format: "%d:%02d", …)`.
//   4. Under it, a `ProgressLine` that empties as time runs out. You need the
//      start too: it is passed in as `from`.
//   5. Reduce Motion: the number may still change every second, but do not
//      animate the bar (`.animation(nil, value:)` or check the environment value
//      `accessibilityReduceMotion`).
//
// You will practise: TimelineView, Date arithmetic, string formatting.
// Read first: `ProgressLine` in App/Components.swift, `Date.clock` (search the
// project). Check it in the #Preview, then spend minutes on a phone with the
// lock on (Screen Time does not work in the simulator).
// ─────────────────────────────────────────────────────────────────────────────

struct UnlockCountdown: View {
    let from: Date
    let until: Date

    var body: some View {
        // TODO(you): replace this with the countdown described above.
        Text("Open until \(until.clock).").caption()
    }
}

#Preview {
    UnlockCountdown(from: .now, until: .now.addingTimeInterval(15 * 60))
        .padding()
        .background(Ink.raised)
}
