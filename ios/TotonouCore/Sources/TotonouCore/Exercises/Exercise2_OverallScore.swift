import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 2 · 総合 · Overall score                    (optionals + closures)
//
// The Status screen has an "overall" number that shows "—" until this works.
//
// Rules
//   • No benchmarks → return nil. (There is nothing to score; 0 would be a lie.)
//   • Otherwise return the weighted average of the percentiles, rounded to the
//     nearest whole number.
//   • The weight of a benchmark comes from `weights[benchmark.stat]`.
//     A stat that is missing from the dictionary has weight 1.
//   • If every weight is 0, return nil.
//
// You will practise: optionals, dictionary lookup with a default, reduce (or a
// for loop — write it both ways and see which you prefer), Int/Double conversion.
//
// Check your work:  cd ios/TotonouCore && swift test --filter Overall
// ─────────────────────────────────────────────────────────────────────────────

public enum BenchmarkScore {
    public static func overall(
        _ benchmarks: [Benchmark],
        weights: [Stat: Double] = [:]
    ) -> Int? {
        // TODO(you): replace this line.
        return nil
    }
}
