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
            You are a blunt coach in a habit app. Reply in one or two sentences, under 30 words. \
            No greeting, no praise, no preamble. Start with the one thing to do today, then the \
            reason. Use only the facts you are given: never invent numbers, events, foods, \
            injuries or plans. If the facts cannot answer the question, say which data is missing. \
            No emojis, no lists.
            """)
        let ask = question.map { "The user asks: \($0)" } ?? "What should they do today?"
        // A hard cap as well as the instruction: the model cannot ramble past ~60 tokens.
        return try await session.respond(to: "Facts (the only things you know):\n\(facts)\n\n\(ask)",
                                         options: GenerationOptions(maximumResponseTokens: 60)).content
    }
}
#endif
