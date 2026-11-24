import Foundation

// Unique skills: named abilities that grow out of how you play.
//
// Skills are data, not code. Each one is a row: a name, a description, which
// measure it grows with, ten level thresholds, an icon and a rarity. The rows
// live in the Supabase `skills` table (supabase/migrations/…_skills.sql) so they
// can be renamed, rebalanced or added from the dashboard; `SkillCatalog.builtIn`
// is the same list shipped in the app, used offline and until the table exists.
//
// What a skill can measure is fixed here, in `SkillMeasure`: every measure is
// something the app records itself or reads from Apple Health, so no skill can
// claim something nobody proved.

/// Everything a skill can grow with.
public enum SkillMeasure: String, CaseIterable, Codable, Sendable {
    // The five stats.
    case strength, endurance, intellect, discipline, recovery
    // Habits the engine counts as quests complete.
    case earlyQuests, nightQuests, onTimeQuests, longQuests, hardQuests
    case mustDoDone, recoveries, bossesDefeated, clearDays, streak
    // Where the proof came from.
    case autoDone, runQuests, stepQuests, mindfulQuests, calendarQuests, reminderQuests
}

/// The current value of every measure. Missing keys count as 0.
public typealias SkillFacts = [SkillMeasure: Int]

public struct SkillDefinition: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let measure: SkillMeasure
    /// The value needed for each level, Lv. 1 first. Up to 10.
    public let thresholds: [Int]
    /// A `Glyph` raw value in the app, such as "dumbbell". Unknown names fall back to a star.
    public let glyph: String
    public let rarity: Rarity

    public init(id: String, name: String, detail: String, measure: SkillMeasure, thresholds: [Int],
                glyph: String, rarity: Rarity) {
        self.id = id
        self.name = name
        self.detail = detail
        self.measure = measure
        self.thresholds = thresholds
        self.glyph = glyph
        self.rarity = rarity
    }

    public func value(_ facts: SkillFacts) -> Int { facts[measure] ?? 0 }

    /// 0 while still locked, otherwise 1 up to the number of thresholds.
    public func level(_ facts: SkillFacts) -> Int {
        let value = value(facts)
        return thresholds.filter { value >= $0 }.count
    }

    /// How far into the current level, 0...1, for a progress bar. 1 at max level.
    public func progress(_ facts: SkillFacts) -> Double {
        let level = level(facts)
        guard level < thresholds.count else { return 1 }
        let low = level == 0 ? 0 : thresholds[level - 1]
        let high = thresholds[level]
        guard high > low else { return 0 }
        return Double(value(facts) - low) / Double(high - low)
    }
}

public enum SkillCatalog {
    /// Level curves, shared by skills of the same kind.
    public enum Curve {
        public static let stat = [5, 10, 20, 30, 45, 60, 80, 100, 130, 160]
        public static let habit = [1, 3, 7, 15, 25, 40, 60, 80, 100, 150]
        public static let rare = [1, 2, 4, 6, 9, 12, 16, 20, 25, 30]
        public static let streak = [3, 7, 14, 21, 30, 45, 60, 100, 180, 365]
        public static let volume = [3, 10, 25, 50, 80, 120, 170, 230, 300, 400]
    }

    private static func skill(_ id: String, _ name: String, _ detail: String, _ measure: SkillMeasure,
                              _ curve: [Int], _ glyph: String, _ rarity: Rarity) -> SkillDefinition {
        SkillDefinition(id: id, name: name, detail: detail, measure: measure, thresholds: curve, glyph: glyph, rarity: rarity)
    }

    /// The skills shipped in the app. The same rows seed the Supabase table.
    public static let builtIn: [SkillDefinition] = [
        // From the five stats.
        skill("ironBody", "Iron Body", "Grows with Strength.", .strength, Curve.stat, "dumbbell", .common),
        skill("secondWind", "Second Wind", "Grows with Endurance.", .endurance, Curve.stat, "mountain", .common),
        skill("sharpMind", "Sharp Mind", "Grows with Intellect.", .intellect, Curve.stat, "book", .common),
        skill("unyielding", "Unyielding", "Grows with Discipline.", .discipline, Curve.stat, "torii", .common),
        skill("stillWater", "Still Water", "Grows with Recovery.", .recovery, Curve.stat, "moon", .common),
        // When and how you finish.
        skill("dawnWalker", "Dawn Walker", "Quests finished before 06:30.", .earlyQuests, Curve.habit, "alarm", .rare),
        skill("nightOwl", "Night Owl", "Quests finished after 21:00.", .nightQuests, Curve.habit, "moon", .common),
        skill("clockwork", "Clockwork", "Quests finished before their time limit.", .onTimeQuests, Curve.volume, "hourglass", .rare),
        skill("deepPractice", "Deep Practice", "Quests of an hour or more.", .longQuests, Curve.habit, "target", .rare),
        skill("overreach", "Overreach", "A- and S-rank quests finished.", .hardQuests, Curve.rare, "bolt", .epic),
        // Keeping your word.
        skill("eternalFlame", "Eternal Flame", "The length of your streak.", .streak, Curve.streak, "flame", .epic),
        skill("oathKeeper", "Oath Keeper", "Must-do quests kept.", .mustDoDone, Curve.habit, "shield", .rare),
        skill("flawless", "Flawless", "Days with every quest cleared.", .clearDays, Curve.habit, "star", .epic),
        skill("phoenix", "Phoenix", "Coming back from the penalty zone.", .recoveries, Curve.rare, "rankUp", .epic),
        skill("giantSlayer", "Giant Slayer", "Bosses defeated.", .bossesDefeated, Curve.rare, "sword", .legendary),
        // Proven by real data.
        skill("livingProof", "Living Proof", "Quests your data proved, not your word.", .autoDone, Curve.volume, "heart", .rare),
        skill("runnersStride", "Runner's Stride", "Runs proven by Apple Health.", .runQuests, Curve.habit, "mountain", .rare),
        skill("wanderer", "Wanderer", "Step goals proven by Apple Health.", .stepQuests, Curve.habit, "watch", .common),
        skill("calmMind", "Calm Mind", "Mindful sessions proven by Apple Health.", .mindfulQuests, Curve.habit, "moon", .rare),
        skill("strategist", "Strategist", "Calendar events turned into finished quests.", .calendarQuests, Curve.habit, "calendar", .common),
        skill("looseEnds", "Loose Ends", "Reminders finished as quests.", .reminderQuests, Curve.habit, "bell", .common),
    ]

    /// Keeps only rows the app can use: a known measure (decoding already
    /// ensures that), at least one threshold, thresholds rising, at most 10 levels.
    public static func valid(_ rows: [SkillDefinition]) -> [SkillDefinition] {
        rows.filter { row in
            !row.thresholds.isEmpty && row.thresholds.count <= 10 && row.thresholds.first! > 0
                && zip(row.thresholds, row.thresholds.dropFirst()).allSatisfy { $0 < $1 }
        }
    }
}
