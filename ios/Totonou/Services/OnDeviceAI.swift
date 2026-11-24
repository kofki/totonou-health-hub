#if canImport(FoundationModels)
import Foundation
import FoundationModels
import TotonouCore

// Apple's on-device language model (Foundation Models, iOS 26). It runs on the
// phone: no account, no key, nothing leaves the device. It only exists where
// Apple Intelligence is switched on, so every use has a non-AI fallback.

@available(iOS 26.0, *)
enum OnDeviceAI {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { true } else { false }
    }
}

// `@Generable` asks the model for a value of this exact shape instead of free
// text, so there is no parsing and no "the AI forgot a field".

@available(iOS 26.0, *)
@Generable
struct GeneratedPlan {
    @Guide(description: "Three or four measurable goals for this chapter, each under nine words")
    var goals: [String]
    @Guide(description: "Four to six small quests to repeat every day that move those goals")
    var quests: [GeneratedQuest]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedQuest {
    @Guide(description: "Short action under six words, for example: Run 5 km easy")
    var title: String
    @Guide(description: "Exactly one of: strength, endurance, intellect, discipline, recovery")
    var stat: String
    @Guide(description: "Hour of the day to do it, from 6 to 22")
    var hour: Int
    @Guide(description: "How many minutes it takes, from 5 to 120")
    var minutes: Int
}

@available(iOS 26.0, *)
struct OnDeviceArcPlanner: ArcPlanner {
    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        let session = LanguageModelSession(instructions: """
            You are the planner inside a habit app that works like a game. The user describes a \
            chapter of their life. Turn it into measurable goals and small daily quests they can \
            actually finish. Be concrete. Plain English. No emojis.
            """)
        let response = try await session.respond(
            to: "Chapter name: \(title)\nIn their words: \(manifesto)",
            generating: GeneratedPlan.self
        )
        let plan = response.content
        let quests = plan.quests.prefix(6).map { quest in
            QuestIdea(title: quest.title, stat: Stat(loose: quest.stat), hour: quest.hour,
                      minutes: quest.minutes, rank: quest.minutes >= 60 ? .b : quest.minutes >= 30 ? .c : .d)
        }
        guard !plan.goals.isEmpty, !quests.isEmpty else { throw CancellationError() }
        return ArcDraft(kanji: "道", goals: Array(plan.goals.prefix(4)), quests: Array(quests), byAI: true)
    }
}

@available(iOS 26.0, *)
struct OnDeviceCoachAdvisor: CoachAdvisor {
    func advise(facts: String, question: String?) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You are a direct, kind coach inside a habit app. You are given facts about the user's \
            week. Answer in two or three short sentences. Use the numbers you are given and do not \
            invent others. End with one specific thing to do today. No emojis, no lists.
            """)
        let ask = question.map { "The user asks: \($0)" } ?? "Give them today's advice."
        return try await session.respond(to: "Facts:\n\(facts)\n\n\(ask)").content
    }
}
#endif
