import Foundation

/// The five character stats. Every quest trains exactly one.
public enum Stat: String, CaseIterable, Codable, Sendable, Identifiable {
    case strength, endurance, intellect, discipline, recovery

    public var id: String { rawValue }

    public var kanji: String {
        switch self {
        case .strength: "力"
        case .endurance: "耐"
        case .intellect: "知"
        case .discipline: "律"
        case .recovery: "癒"
        }
    }

    public var title: String { rawValue.capitalized }
}

/// Difficulty rank, E (trivial) to S (brutal). Also used as the hunter rank.
public enum Rank: String, CaseIterable, Codable, Sendable, Comparable {
    case e = "E", d = "D", c = "C", b = "B", a = "A", s = "S"

    private var order: Int { Rank.allCases.firstIndex(of: self)! }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.order < rhs.order }

    /// XP for finishing a quest of this rank.
    public var xp: Int { [10, 20, 35, 60, 100, 200][order] }

    /// Stat points for finishing a quest of this rank.
    public var statPoints: Int { order + 1 }

    /// Minutes of social-app time a quest of this rank unlocks.
    public var earnedMinutes: Int { [5, 10, 15, 20, 30, 45][order] }

    /// The difficulty in a word, shown next to the rank letter.
    public var difficulty: String {
        ["Trivial", "Easy", "Normal", "Hard", "Elite", "Brutal"][order]
    }

    /// Hunter rank for a character level: a new rank every 10 levels.
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
