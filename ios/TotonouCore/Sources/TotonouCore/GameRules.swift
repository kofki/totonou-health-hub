import Foundation

/// The seven character stats. Every quest trains exactly one.
public enum Stat: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Raw power: lifting, strength sessions.
    case strength
    /// Speed and coordination: sports, mobility, skating, volleyball.
    case agility
    /// Stamina and health: cardio, steps, sleep. Sets your max HP.
    case vitality
    /// Learning and solving: study, deep work, shipping.
    case intelligence
    /// Judgement and calm: reflection, journaling, meditation, planning.
    case wisdom
    /// People: calls, outreach, posting, social plans.
    case charisma
    /// Doing what you said: must-dos, streaks, hard quests, screen limits.
    case willpower

    // The five stats before 2026-11-25, and what each became. Quests and
    // profiles saved then still read back (see init below), and code written
    // with the old names (`.endurance`) still compiles.
    public static let endurance = Stat.vitality
    public static let intellect = Stat.intelligence
    public static let discipline = Stat.willpower
    public static let recovery = Stat.wisdom

    /// Also accepts the old names, so data saved before the change still loads.
    /// Writing `init?(rawValue:)` ourselves replaces the one Swift would make.
    public init?(rawValue: String) {
        switch rawValue {
        case "strength": self = .strength
        case "agility": self = .agility
        case "vitality", "endurance": self = .vitality
        case "intelligence", "intellect": self = .intelligence
        case "wisdom", "recovery": self = .wisdom
        case "charisma": self = .charisma
        case "willpower", "discipline": self = .willpower
        default: return nil
        }
    }

    public var id: String { rawValue }

    public var kanji: String {
        switch self {
        case .strength: "力"
        case .agility: "速"
        case .vitality: "命"
        case .intelligence: "知"
        case .wisdom: "悟"
        case .charisma: "魅"
        case .willpower: "志"
        }
    }

    public var title: String { rawValue.capitalized }

    /// Three letters, for tight places: "STR", "AGI", "VIT", "INT", "WIS", "CHA", "WIL".
    public var short: String { String(rawValue.prefix(3)).uppercased() }
}

/// Difficulty rank, E (trivial) to S (brutal), and the human rank.
///
/// F- is a human rank only: everyone starts there and leaves it at level 10.
/// No quest is ever F-, so the quest tables below give it E's values.
public enum Rank: String, CaseIterable, Codable, Sendable, Comparable {
    case f = "F-", e = "E", d = "D", c = "C", b = "B", a = "A", s = "S"

    private var order: Int { Rank.allCases.firstIndex(of: self)! }

    /// The ranks a quest can have, E to S.
    public static let questRanks: [Rank] = [.e, .d, .c, .b, .a, .s]

    /// Position among quest ranks; F- counts as E.
    private var questOrder: Int { max(order - 1, 0) }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.order < rhs.order }

    /// XP for finishing a quest of this rank.
    public var xp: Int { [10, 20, 35, 60, 100, 200][questOrder] }

    /// Stat points for finishing a quest of this rank.
    public var statPoints: Int { questOrder + 1 }

    /// Minutes of social-app time a quest of this rank unlocks.
    public var earnedMinutes: Int { [5, 10, 15, 20, 30, 45][questOrder] }

    /// The difficulty in a word, shown next to the rank letter.
    public var difficulty: String {
        ["Trivial", "Easy", "Normal", "Hard", "Elite", "Brutal"][questOrder]
    }

    /// "E-Rank", or "F- Rank" so the minus does not run into the dash.
    public var label: String { self == .f ? "F- Rank" : "\(rawValue)-Rank" }

    /// Human rank for a character level: F- until level 10, then a new rank every 10 levels.
    public static func forLevel(_ level: Int) -> Rank {
        let index = min(max(level, 1) / 10, Rank.allCases.count - 1)
        return Rank.allCases[index]
    }
}

public struct LevelProgress: Equatable, Sendable {
    public let level: Int
    /// XP earned inside the current level.
    public let into: Int
    /// XP the current level needs in total.
    public let needed: Int

    public var fraction: Double { needed == 0 ? 0 : Double(into) / Double(needed) }
}

/// How total XP turns into a level. Each level costs 40 XP more than the last.
public enum LevelCurve {
    public static func xpToAdvance(from level: Int) -> Int {
        100 + (max(level, 1) - 1) * 40
    }

    public static func progress(forTotalXP totalXP: Int) -> LevelProgress {
        var level = 1
        var remaining = max(totalXP, 0)
        while remaining >= xpToAdvance(from: level) {
            remaining -= xpToAdvance(from: level)
            level += 1
        }
        return LevelProgress(level: level, into: remaining, needed: xpToAdvance(from: level))
    }
}

/// One "you vs. people your age" comparison.
public struct Benchmark: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    /// 0–100. Higher is always better, whatever the raw metric is.
    public let percentile: Int
    public let stat: Stat

    public init(id: String, title: String, value: String, percentile: Int, stat: Stat) {
        self.id = id
        self.title = title
        self.value = value
        self.percentile = percentile
        self.stat = stat
    }
}
