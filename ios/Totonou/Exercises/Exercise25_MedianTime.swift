import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 25 · Median time                           (sorting, arrays, optionals)
//
// The reaction test (Coach → Tests → Reaction) records five tap times in
// milliseconds. The middle one is fairer than the average: one sleepy 600 ms
// tap drags an average up, but barely moves the middle. Right now the app
// uses the average. Return the median instead.
//
// Build it
//   1. No times: return nil.
//   2. Sort a copy of the times (`sorted()` returns a new array).
//   3. An odd count: the middle element. Five times → index 2.
//   4. An even count: the average of the two middle elements.
//
// You will practise: sorted(), integer division for an index, odd and even
// counts, optionals.
// Read first: `ReactionTest` in Features/Coach/MindTests.swift, which calls it.
// How to check: do the reaction test with one deliberately slow tap; the saved
// time should be close to your other four, not pulled up by the slow one.
// ─────────────────────────────────────────────────────────────────────────────

func medianTime(_ times: [Double]) -> Double? {
    // TODO(you): Exercise 25.
    nil
}
