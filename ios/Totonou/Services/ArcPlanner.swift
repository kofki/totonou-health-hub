import Foundation
import TotonouCore

/// One quest the planner proposes: what, which stat it trains, and when.
struct QuestIdea: Sendable, Equatable, Identifiable {
    var title: String
    var stat: Stat
    var hour: Int
    var minute: Int = 0
    var minutes: Int = 15
    var rank: Rank = .d

    var id: String { title }
    var clock: String { String(format: "%02d:%02d", hour, minute) }

    /// Stored on the arc as one line of text, which keeps the database simple.
    var line: String { [title, stat.rawValue, "\(hour)", "\(minute)", "\(minutes)", rank.rawValue].joined(separator: "|") }

    init(title: String, stat: Stat, hour: Int, minute: Int = 0, minutes: Int = 15, rank: Rank = .d) {
        self.title = title
        self.stat = stat
        self.hour = min(max(hour, 5), 23)
        self.minute = min(max(minute, 0), 59)
        self.minutes = min(max(minutes, 0), 240)
        self.rank = rank
    }

    init?(line: String) {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 6, let stat = Stat(rawValue: parts[1]), let hour = Int(parts[2]),
              let minute = Int(parts[3]), let minutes = Int(parts[4]), let rank = Rank(rawValue: parts[5]) else { return nil }
        self.init(title: parts[0], stat: stat, hour: hour, minute: minute, minutes: minutes, rank: rank)
    }
}

/// What the planner hands back after reading your chapter.
struct ArcDraft: Sendable {
    var kanji: String
    var goals: [String]
    var quests: [QuestIdea]
    /// True when the on-device language model wrote it, false for the keyword rules.
    var byAI: Bool
}

/// Turns free text into goals and daily quests.
protocol ArcPlanner: Sendable {
    func plan(title: String, manifesto: String) async throws -> ArcDraft
}

enum Planners {
    /// The best planner this device has: Apple's on-device model where it is
    /// available, with the keyword rules as a safety net.
    static func arc() -> any ArcPlanner {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceAI.isAvailable {
            return FallbackArcPlanner(first: OnDeviceArcPlanner(), then: RuleBasedArcPlanner())
        }
        #endif
        return RuleBasedArcPlanner()
    }
}

/// Tries one planner and, if it throws, quietly uses another.
struct FallbackArcPlanner: ArcPlanner {
    let first: any ArcPlanner
    let then: any ArcPlanner

    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        do { return try await first.plan(title: title, manifesto: manifesto) }
        catch { return try await then.plan(title: title, manifesto: manifesto) }
    }
}

/// Reads keywords. No intelligence, but it always works, offline and instantly.
struct RuleBasedArcPlanner: ArcPlanner {
    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        try await Task.sleep(for: .seconds(0.8))
        let text = (title + " " + manifesto).lowercased()
        func mentions(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        var goals: [String] = []
        var quests: [QuestIdea] = []

        if mentions("gym", "lift", "strong", "muscle", "lean", "fat", "weight") {
            goals += ["Train four days a week", "Body fat down two points"]
            quests += [QuestIdea(title: "Morning mobility", stat: .strength, hour: 7, minute: 30, minutes: 10, rank: .e),
                       QuestIdea(title: "Strength session", stat: .strength, hour: 18, minutes: 45, rank: .c)]
        }
        if mentions("run", "cardio", "5k", "10k", "endurance", "marathon") {
            goals.append("5 km under 25:00")
            quests.append(QuestIdea(title: "Easy run", stat: .endurance, hour: 17, minute: 30, minutes: 35, rank: .c))
        }
        if mentions("study", "exam", "school", "learn", "course", "work", "code", "read") {
            goals.append("One deep-work block every weekday")
            quests.append(QuestIdea(title: "Deep work", stat: .intellect, hour: 9, minutes: 90, rank: .b))
        }
        if mentions("sleep", "rest", "tired", "energy") {
            goals.append("Seven and a half hours of sleep")
            quests.append(QuestIdea(title: "Screens off", stat: .recovery, hour: 22, minute: 30, minutes: 30))
        }
        if mentions("phone", "scroll", "screen", "instagram", "tiktok", "social") {
            goals.append("Screen time under two hours a day")
            quests.append(QuestIdea(title: "Phone out of the bedroom", stat: .discipline, hour: 22, minutes: 5))
        }
        if goals.isEmpty {
            goals = ["Show up every day", "One hard thing before noon", "In bed by 23:00"]
            quests = [QuestIdea(title: "One hard thing", stat: .discipline, hour: 9, minutes: 45, rank: .c),
                      QuestIdea(title: "Walk 20 min", stat: .endurance, hour: 13, minutes: 20, rank: .e),
                      QuestIdea(title: "Evening review", stat: .discipline, hour: 21, minutes: 5, rank: .e)]
        }
        return ArcDraft(kanji: "道", goals: goals, quests: quests, byAI: false)
    }
}

extension Stat {
    /// A best guess from loose text, for anything a language model returns.
    init(loose text: String) {
        let text = text.lowercased()
        self = Stat.allCases.first { text.contains($0.rawValue) } ?? .discipline
    }
}
