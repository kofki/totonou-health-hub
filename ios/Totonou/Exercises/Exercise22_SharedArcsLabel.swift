import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 22 · Shared arcs label                     (map, Set, string joining)
//
// A quest can live in one arc and also count toward objectives in others
// (Objective.sharedTitles). On the Arcs screen, each plan line can say so.
// Make this function return that line from the objectives it also counts for.
//
// Build it
//   1. No objectives: return nil, so nothing is shown.
//   2. Take each objective's arc title (`objective.arc?.title`). One arc can
//      have two of these objectives: name each arc once, in the order first seen.
//   3. One arc: "Also for Winter Arc". Two: "Also for Winter Arc and Founder".
//      More: "Also for Winter Arc, Founder and 1 more".
//
// You will practise: compactMap, removing duplicates while keeping order
// (a Set of the ones seen so far), building a sentence from a list.
// Read first: `ClaudeActivity.message` in Services/ClaudeChanges.swift builds
// a very similar sentence; `PlanLine` in Features/Arcs/ArcsView.swift shows it.
// How to check: in an arc's detail, under an objective, tap "Also count a quest
// from another arc" and pick one. Open the other arc: its plan line says it.
// ─────────────────────────────────────────────────────────────────────────────

func sharedArcsLabel(_ objectives: [Objective]) -> String? {
    // TODO(you): Exercise 22.
    nil
}
