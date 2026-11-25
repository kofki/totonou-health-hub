import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 21 · Plan steps label                      (computed strings, plurals)
//
// A daily quest in an arc's plan can now carry a checklist (`QuestIdea.steps`),
// which Claude fills in through the connector. On the Arcs screen, each plan
// line shows "Mon Wed Fri · Strength sessions" under its title, and nothing
// says it has steps. Make this function return the words for that.
//
// Build it
//   1. No steps: return nil, so the plan line shows nothing extra.
//   2. One step: "1 step". More: "3 steps".
//   3. Add the minutes of every step together and append them: "3 steps, 32 min".
//      `reduce(0) { $0 + $1.minutes }` adds them; a plain `for` loop works too.
//
// You will practise: optionals as "nothing to show", plurals, reduce.
// Read first: `QuestIdea` in Services/ArcPlanner.swift and `PlanLine` in
// Features/Arcs/ArcsView.swift, which already joins this with the days label.
// How to check: the #Preview below, then an arc whose plan has steps.
// ─────────────────────────────────────────────────────────────────────────────

func planStepsLabel(_ steps: [QuestIdea.StepIdea]) -> String? {
    // TODO(you): Exercise 21.
    nil
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Text(planStepsLabel([]) ?? "(nothing)")
        Text(planStepsLabel([.init(title: "Bench press 4 x 6", minutes: 12)]) ?? "(nothing)")
        Text(planStepsLabel([.init(title: "Bench", minutes: 12), .init(title: "Rows", minutes: 10),
                             .init(title: "Curls", minutes: 10)]) ?? "(nothing)")
    }
    .padding()
}
