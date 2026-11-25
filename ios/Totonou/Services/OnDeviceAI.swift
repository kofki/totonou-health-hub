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
    @Guide(description: "One to three outcomes for this chapter, each under nine words, with a number in it, for example: Squat 100 kg")
    var goals: [String]
    @Guide(description: "Two to four counts to hit every day or every week that lead to those outcomes")
    var objectives: [GeneratedObjective]
    @Guide(description: "Four to seven specific quests, each counting toward one objective, on the weekdays it happens")
    var quests: [GeneratedQuest]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedObjective {
    @Guide(description: "What is counted, under five words, for example: Strength sessions")
    var title: String
    @Guide(description: "Exactly one of: day, week")
    var period: String
    @Guide(description: "How many per period, from 1 to 7")
    var target: Int
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
    @Guide(description: "Title of the objective it counts toward, copied exactly")
    var objective: String
    @Guide(description: "Weekdays it happens, 1 is Monday and 7 is Sunday; all seven for every day")
    var weekdays: [Int]
}

@available(iOS 26.0, *)
struct OnDeviceArcPlanner: ArcPlanner {
    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        let session = LanguageModelSession(instructions: """
            You are the planner inside a habit app that works like a game. The user describes a \
            chapter of their life. Turn it into outcomes with numbers, daily or weekly counts that \
            lead to them, and specific quests that each count toward one of those counts. A weekly \
            count of four needs quests on four weekdays, not every day. Never write vague quests \
            like "Deep work" or "Exercise": say what exactly, how long, how hard. Plain English. No emojis.
            """)
        let response = try await session.respond(
            to: "Chapter name: \(title)\nIn their words: \(manifesto)",
            generating: GeneratedPlan.self
        )
        let plan = response.content
        let objectives = plan.objectives.prefix(4).map { objective in
            ObjectiveIdea(title: objective.title, period: objective.period.lowercased() == "day" ? .day : .week,
                          target: min(max(objective.target, 1), 7))
        }
        let titles = Set(objectives.map(\.title))
        let quests = plan.quests.prefix(7).map { quest in
            QuestIdea(title: quest.title, stat: Stat(loose: quest.stat), hour: quest.hour,
                      minutes: quest.minutes, rank: quest.minutes >= 60 ? .b : quest.minutes >= 30 ? .c : .d,
                      objective: titles.contains(quest.objective) ? quest.objective : nil,
                      weekdays: Set(quest.weekdays).count >= 7 ? [] : Set(quest.weekdays))
        }
        guard !plan.goals.isEmpty, !quests.isEmpty else { throw CancellationError() }
        return ArcDraft(kanji: "道", goals: Array(plan.goals.prefix(4)), objectives: Array(objectives),
                        quests: Array(quests), byAI: true)
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
