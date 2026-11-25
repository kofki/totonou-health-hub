import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 24 · Standing label                        (conditionals, rounding)
//
// The Coach's benchmarks turn each of your numbers into a percentile: how many
// men in 100 you do better than. Right now every row says it plainly, "Better
// than 72 in 100". Make it read like a ranking instead.
//
// Build it
//   1. 50 or more: "Top 28%" (100 minus the percentile, rounded).
//   2. Under 50: "Bottom 30%" (the percentile, rounded).
//   3. 99 or more: "Top 1%". Never "Top 0%".
//   4. Exactly in the middle band, 45 to 55: "About average".
//   Return the String; returning nil keeps the plain wording.
//
// You will practise: if / else if chains (or a switch with ranges), rounding a
// Double to an Int, string interpolation.
// Read first: `NormRow` in Features/Coach/BenchmarksView.swift, which shows it,
// and `Norm.percentile(of:)` in TotonouCore/Norms.swift, which makes the number.
// How to check: Coach → Benchmarks, once Health or your lifts give a value.
// ─────────────────────────────────────────────────────────────────────────────

func standingLabel(percentile: Double) -> String? {
    // TODO(you): Exercise 24.
    nil
}
