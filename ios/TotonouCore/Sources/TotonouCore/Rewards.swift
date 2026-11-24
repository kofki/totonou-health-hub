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

/// Unique skills: named abilities that grow out of how you play, not out of
/// any one quest. Each has its own measure and its own thresholds, Lv. 1 to 10.
public enum Skill: String, CaseIterable, Sendable {
    case ironBody, secondWind, sharpMind, unyielding, stillWater
    case dawnWalker, eternalFlame, livingProof, giantSlayer, phoenix, oathKeeper, flawless

    public var name: String {
        switch self {
        case .ironBody: "Iron Body"
        case .secondWind: "Second Wind"
        case .sharpMind: "Sharp Mind"
        case .unyielding: "Unyielding"
        case .stillWater: "Still Water"
        case .dawnWalker: "Dawn Walker"
        case .eternalFlame: "Eternal Flame"
        case .livingProof: "Living Proof"
        case .giantSlayer: "Giant Slayer"
        case .phoenix: "Phoenix"
        case .oathKeeper: "Oath Keeper"
        case .flawless: "Flawless"
        }
    }

    public var detail: String {
        switch self {
        case .ironBody: "Grows with Strength."
        case .secondWind: "Grows with Endurance."
        case .sharpMind: "Grows with Intellect."
        case .unyielding: "Grows with Discipline."
        case .stillWater: "Grows with Recovery."
        case .dawnWalker: "Quests finished before 06:30."
        case .eternalFlame: "The length of your streak."
        case .livingProof: "Quests your data proved, not your word."
        case .giantSlayer: "Bosses defeated."
        case .phoenix: "Coming back from the penalty zone."
        case .oathKeeper: "Must-do quests kept."
        case .flawless: "Days with every quest cleared."
        }
    }

    /// The count needed for each level, Lv. 1 first.
    public var thresholds: [Int] {
        switch self {
        case .ironBody, .secondWind, .sharpMind, .unyielding, .stillWater:
            [5, 10, 20, 30, 45, 60, 80, 100, 130, 160]
        case .eternalFlame:
            [3, 7, 14, 21, 30, 45, 60, 100, 180, 365]
        case .giantSlayer, .phoenix:
            [1, 2, 4, 6, 9, 12, 16, 20, 25, 30]
        default:
            [1, 3, 7, 15, 25, 40, 60, 80, 100, 150]
        }
    }

    public func measure(_ facts: SkillFacts) -> Int {
        switch self {
        case .ironBody: facts.strength
        case .secondWind: facts.endurance
        case .sharpMind: facts.intellect
        case .unyielding: facts.discipline
        case .stillWater: facts.recovery
        case .dawnWalker: facts.earlyQuests
        case .eternalFlame: facts.streak
        case .livingProof: facts.autoDone
        case .giantSlayer: facts.bossesDefeated
        case .phoenix: facts.recoveries
        case .oathKeeper: facts.mustDoDone
        case .flawless: facts.clearDays
        }
    }

    /// 0 while still locked, otherwise 1...10.
    public func level(_ facts: SkillFacts) -> Int {
        let value = measure(facts)
        return thresholds.filter { value >= $0 }.count
    }

    /// How far into the current level, 0...1, for a progress bar. 1 at max level.
    public func progress(_ facts: SkillFacts) -> Double {
        let value = measure(facts)
        let level = self.level(facts)
        guard level < thresholds.count else { return 1 }
        let low = level == 0 ? 0 : thresholds[level - 1]
        let high = thresholds[level]
        return Double(value - low) / Double(high - low)
    }
}

/// The numbers skills are measured on.
public struct SkillFacts: Equatable, Sendable {
    public var strength = 0, endurance = 0, intellect = 0, discipline = 0, recovery = 0
    public var earlyQuests = 0, streak = 0, autoDone = 0, bossesDefeated = 0
    public var recoveries = 0, mustDoDone = 0, clearDays = 0

    public init(strength: Int = 0, endurance: Int = 0, intellect: Int = 0, discipline: Int = 0, recovery: Int = 0,
                earlyQuests: Int = 0, streak: Int = 0, autoDone: Int = 0, bossesDefeated: Int = 0,
                recoveries: Int = 0, mustDoDone: Int = 0, clearDays: Int = 0) {
        self.strength = strength
        self.endurance = endurance
        self.intellect = intellect
        self.discipline = discipline
        self.recovery = recovery
        self.earlyQuests = earlyQuests
        self.streak = streak
        self.autoDone = autoDone
        self.bossesDefeated = bossesDefeated
        self.recoveries = recoveries
        self.mustDoDone = mustDoDone
        self.clearDays = clearDays
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

/// How hard an achievement is to get. Shown as its colour and label.
public enum Rarity: String, CaseIterable, Sendable {
    case common, rare, epic, legendary

    public var title: String { rawValue.capitalized }
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

    public var rarity: Rarity {
        switch self {
        case .firstQuest, .firstAuto, .upAtSix: .common
        case .firstBoss, .recovered, .streak7, .mustDo10, .level10: .rare
        case .fullWeek, .quests100, .rankC: .epic
        case .streak30: .legendary
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
