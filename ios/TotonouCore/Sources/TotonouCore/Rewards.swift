import Foundation

// What progress pays. Everything here is a pure function of numbers and dates,
// so it can be tested without SwiftData or a phone. QuestEngine applies it.
//
// Two currencies, on purpose: XP only ever goes up and decides your level;
// banked minutes are spent on screen time. Spending never touches XP.

/// What reaching one level gives you.
public struct LevelReward: Equatable, Sendable {
    public let level: Int
    /// Points you choose where to put. Always 1.
    public let statPoints: Int
    /// Screen time added to the bank.
    public let minutes: Int
    /// A title you can wear, every 5 levels.
    public let title: String?
    /// Every 10 levels the hunter rank changes (E → D → … → S).
    public let isRankUp: Bool
    /// Rank-ups also give a streak freeze and an emergency pass.
    public let freezes: Int
    public let passes: Int
}

public enum Rewards {
    public static let minutesPerLevel = 10
    public static let dailyClearXP = 25
    public static let dailyClearMinutes = 10
    /// Like Duolingo, you can hold at most two freezes, so they stay precious.
    public static let maxFreezes = 2

    public static func forLevel(_ level: Int) -> LevelReward {
        let rankUp = level % 10 == 0 && level <= 50
        return LevelReward(
            level: level,
            statPoints: 1,
            minutes: minutesPerLevel,
            title: Titles.unlocked(at: level),
            isRankUp: rankUp,
            freezes: rankUp ? 1 : 0,
            passes: rankUp ? 1 : 0
        )
    }

    /// Every level crossed between two levels, in order. One big quest can cross several.
    public static func rewards(from before: Int, to after: Int) -> [LevelReward] {
        guard after > before else { return [] }
        return ((before + 1)...after).map(forLevel)
    }

    /// Stats finally matter: each full 10 points in a quest's stat adds 5% to its XP.
    public static func masteryMultiplier(statValue: Int) -> Double {
        1 + 0.05 * Double(max(statValue, 0) / 10)
    }

    public static func questXP(rank: Rank, statValue: Int) -> Int {
        Int((Double(rank.xp) * masteryMultiplier(statValue: statValue)).rounded())
    }
}

/// Titles earned every 5 levels. Worn next to your name.
public enum Titles {
    public static let byLevel: [Int: String] = [
        5: "Awakened", 10: "Hunter", 15: "Early Riser", 20: "Iron Will", 25: "Unbroken",
        30: "Pathfinder", 35: "Storm Runner", 40: "Quiet Mind", 45: "Mountain Heart", 50: "Totonoi",
    ]

    public static func unlocked(at level: Int) -> String? {
        guard level > 0, level % 5 == 0 else { return nil }
        return byLevel[level] ?? "Legend \(level)"
    }

    /// The next title above `level`, for "Next title at level 20: Iron Will".
    public static func next(after level: Int) -> (level: Int, title: String) {
        let next = (level / 5 + 1) * 5
        return (next, unlocked(at: next) ?? "")
    }
}

/// A chest for keeping a streak alive.
public struct StreakMilestone: Equatable, Sendable {
    public let days: Int
    public let minutes: Int
    public let freezes: Int
}

public enum StreakMilestones {
    /// Big moments only at milestones; ordinary days stay modest.
    public static let all: [StreakMilestone] = [
        StreakMilestone(days: 3, minutes: 10, freezes: 0),
        StreakMilestone(days: 7, minutes: 20, freezes: 1),
        StreakMilestone(days: 14, minutes: 30, freezes: 1),
        StreakMilestone(days: 30, minutes: 45, freezes: 1),
        StreakMilestone(days: 60, minutes: 60, freezes: 1),
        StreakMilestone(days: 100, minutes: 90, freezes: 1),
    ]

    /// The milestone a streak of exactly this length opens, if any.
    public static func reached(streak: Int) -> StreakMilestone? {
        all.first { $0.days == streak }
    }
}

public enum StreakFreeze {
    /// Days a freeze should cover so the streak survives, or `[]` if freezes cannot save it.
    ///
    /// Walks back from yesterday over missed days until it meets a day that counts
    /// (completed or already frozen). If there was a streak behind those missed days
    /// and there are enough freezes for all of them, those days are returned.
    public static func daysToFreeze(
        completionDays: [Date],
        frozenDays: [Date],
        available: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard available > 0 else { return [] }
        let counted = Set((completionDays + frozenDays).map { calendar.startOfDay(for: $0) })
        guard let earliest = counted.min() else { return [] }
        var day = calendar.startOfDay(for: today)
        var missed: [Date] = []
        while true {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return [] }
            day = previous
            if counted.contains(day) { break }
            if day < earliest { return [] }
            missed.append(day)
            if missed.count > available { return [] }
        }
        return missed
    }
}

/// Fixed achievements. Each one also gives a title.
public enum Achievement: String, CaseIterable, Codable, Sendable {
    case firstQuest, firstAuto, firstBoss, recovered
    case streak7, streak30, fullWeek, upAtSix
    case quests100, mustDo10, level10, rankC

    public var title: String {
        switch self {
        case .firstQuest: "First step"
        case .firstAuto: "First auto"
        case .firstBoss: "First boss"
        case .recovered: "Recovered"
        case .streak7: "7-day streak"
        case .streak30: "30-day streak"
        case .fullWeek: "Full week"
        case .upAtSix: "Up at 6"
        case .quests100: "100 quests"
        case .mustDo10: "Kept my word"
        case .level10: "Level 10"
        case .rankC: "C-Rank"
        }
    }

    public var detail: String {
        switch self {
        case .firstQuest: "Finish your first quest."
        case .firstAuto: "A quest finished itself from real data."
        case .firstBoss: "Defeat a boss."
        case .recovered: "Clear a recovery quest."
        case .streak7: "Keep a 7-day streak."
        case .streak30: "Keep a 30-day streak."
        case .fullWeek: "Clear every quest 7 days running."
        case .upAtSix: "Finish a quest before 06:30."
        case .quests100: "Finish 100 quests."
        case .mustDo10: "Finish 10 must-do quests."
        case .level10: "Reach level 10."
        case .rankC: "Reach C-Rank (level 20)."
        }
    }
}

/// The counts achievements are judged on.
public struct AchievementFacts: Equatable, Sendable {
    public var questsDone = 0
    public var autoDone = 0
    public var bossesDefeated = 0
    public var recoveries = 0
    public var streak = 0
    public var clearStreak = 0
    public var earlyQuests = 0
    public var mustDoDone = 0
    public var level = 1

    public init(questsDone: Int = 0, autoDone: Int = 0, bossesDefeated: Int = 0, recoveries: Int = 0,
                streak: Int = 0, clearStreak: Int = 0, earlyQuests: Int = 0, mustDoDone: Int = 0, level: Int = 1) {
        self.questsDone = questsDone
        self.autoDone = autoDone
        self.bossesDefeated = bossesDefeated
        self.recoveries = recoveries
        self.streak = streak
        self.clearStreak = clearStreak
        self.earlyQuests = earlyQuests
        self.mustDoDone = mustDoDone
        self.level = level
    }

    public var earned: Set<Achievement> {
        var set = Set<Achievement>()
        if questsDone >= 1 { set.insert(.firstQuest) }
        if autoDone >= 1 { set.insert(.firstAuto) }
        if bossesDefeated >= 1 { set.insert(.firstBoss) }
        if recoveries >= 1 { set.insert(.recovered) }
        if streak >= 7 { set.insert(.streak7) }
        if streak >= 30 { set.insert(.streak30) }
        if clearStreak >= 7 { set.insert(.fullWeek) }
        if earlyQuests >= 1 { set.insert(.upAtSix) }
        if questsDone >= 100 { set.insert(.quests100) }
        if mustDoDone >= 10 { set.insert(.mustDo10) }
        if level >= 10 { set.insert(.level10) }
        if level >= 20 { set.insert(.rankC) }
        return set
    }
}
