import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 15 · Cloud arc planner                  (Codable, async/await, throws)
//
// Your iPhone 14 has no Apple Intelligence, so "New arc" plans with keyword
// rules. The `ai` Edge Function can already write a real plan; nothing in the
// app asks it yet. This type is that missing piece. Until you write it, `plan`
// throws, and `FallbackArcPlanner` quietly uses the rules, so the app still runs.
//
// For a plan request the function answers with JSON in exactly this shape:
//
//   { "goals":  ["Run 5 km under 25:00", "Sleep seven hours"],
//     "quests": [ { "title": "Easy run", "stat": "endurance", "hour": 17, "minutes": 35 } ] }
//
// Build it
//   1. Declare private Decodable structs whose property names match that JSON:
//      one for the whole answer, one for a single quest.
//   2. Ask the backend: send `.plan(title:manifesto:)` and await the Data.
//   3. Decode the Data with JSONDecoder. Let a decoding error throw; do not
//      catch it here (think about who is waiting to catch it, and why).
//   4. Turn each decoded quest into a `QuestIdea`. `stat` arrives as text:
//      there is already an initialiser for loose text. Pick the rank from the
//      minutes the same way the on-device planner does.
//   5. Keep at most four goals and six quests. If either list is empty, throw
//      `CloudAIError.badAnswer`.
//   6. Return an `ArcDraft` with `byAI: true`.
//   7. Extra, once 1-6 work: the answer also carries "objectives" (title,
//      period "day" or "week", target) and each quest an "objective" title and
//      "weekdays" (1 = Monday). Decode them into `ObjectiveIdea` and the
//      matching `QuestIdea` fields, the way `OnDeviceArcPlanner` does.
//
// You will practise: Decodable, async/await, throwing and propagating errors,
// map and prefix.
// Read first: `CloudCoachAdvisor` in Services/CloudAI.swift (the same job for
// one string), `OnDeviceArcPlanner` in Services/OnDeviceAI.swift (steps 4-6).
// Check it in the #Preview below: it should list two goals and three quests
// instead of "Threw: notWritten". Then, once the function is deployed, make a
// new arc on your phone: the caption under the plan reads "Written by AI."
// ─────────────────────────────────────────────────────────────────────────────

struct CloudArcPlanner: ArcPlanner {
    let backend: any AIBackend

    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        // TODO(you): replace this line with steps 1-6.
        throw CloudAIError.notWritten
    }
}

// MARK: Preview only

/// Answers every request with one fixed plan, so the preview needs no network.
/// A stand-in for previews; the app itself never uses it.
private struct CannedAIBackend: AIBackend {
    func send(_ request: AIRequest) async throws -> Data {
        Data("""
        { "goals": ["Run 5 km under 25:00", "Sleep seven hours"],
          "quests": [
            { "title": "Easy run", "stat": "endurance", "hour": 17, "minutes": 35 },
            { "title": "Deep work", "stat": "intellect", "hour": 9, "minutes": 90 },
            { "title": "Screens off", "stat": "recovery", "hour": 22, "minutes": 10 } ] }
        """.utf8)
    }
}

private struct PlannerCheck: View {
    @State private var result = "Planning…"

    var body: some View {
        Text(result)
            .font(.text(16))
            .padding()
            // `.task` runs async work when the view appears and cancels it when
            // the view goes away, which a plain `onAppear` cannot do.
            .task {
                do {
                    let draft = try await CloudArcPlanner(backend: CannedAIBackend())
                        .plan(title: "Winter Arc", manifesto: "Run faster and sleep more.")
                    let quests = draft.quests.map { "\($0.clock)  \($0.title)  \($0.stat.rawValue)  rank \($0.rank.rawValue)" }
                    result = (draft.goals + quests).joined(separator: "\n")
                } catch {
                    result = "Threw: \(error)"
                }
            }
    }
}

#Preview {
    PlannerCheck()
}
