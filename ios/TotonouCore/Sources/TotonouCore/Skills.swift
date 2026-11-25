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
    // Workouts recorded in Apple Health, all time, by type.
    case workouts, cyclingWorkouts, swimWorkouts, danceWorkouts, martialArtsWorkouts
    // Sports, in minutes played, from Apple Health and Garmin (see `Sport`).
    case volleyballMinutes, surfMinutes, skateMinutes, snowboardMinutes, skiMinutes, climbMinutes
    case basketballMinutes, soccerMinutes, racquetMinutes, paddleMinutes, hikeMinutes, yogaMinutes, golfMinutes
    // Volleyball's branches: games played, the longest one, games in the last 30 days.
    case volleyballSessions, volleyballLongest, volleyballRecent

    /// Measures counted in minutes, shown as hours played.
    public var isMinutes: Bool { rawValue.hasSuffix("Minutes") }

    /// The measures that come from sport sessions (`Sport.facts`).
    public var isSport: Bool { isMinutes || rawValue.hasPrefix("volleyball") }
}

/// The sports that grow a skill. Running and plain gym work are left out on
/// purpose: these are the things you can say you know how to do.
public enum Sport: String, CaseIterable, Sendable {
    case volleyball, surf, skate, snowboard, ski, climb, basketball, soccer, racquet, paddle, hike, yoga, golf

    public var minutes: SkillMeasure {
        switch self {
        case .volleyball: .volleyballMinutes
        case .surf: .surfMinutes
        case .skate: .skateMinutes
        case .snowboard: .snowboardMinutes
        case .ski: .skiMinutes
        case .climb: .climbMinutes
        case .basketball: .basketballMinutes
        case .soccer: .soccerMinutes
        case .racquet: .racquetMinutes
        case .paddle: .paddleMinutes
        case .hike: .hikeMinutes
        case .yoga: .yogaMinutes
        case .golf: .golfMinutes
        }
    }

    /// A Garmin activity type key ("volleyball", "resort_snowboarding",
    /// "inline_skating"…) to a sport, or nil for ones that grow no skill.
    public static func from(garminType key: String) -> Sport? {
        let key = key.lowercased()
        func has(_ parts: String...) -> Bool { parts.contains { key.contains($0) } }
        if has("volleyball") { return .volleyball }
        if has("surf") { return .surf }
        if has("snowboard") { return .snowboard }
        // "skate_skiing" is cross-country skiing, not skating.
        if has("skat") && !has("ski") { return .skate }
        if has("ski") { return .ski }
        if has("climb", "boulder") { return .climb }
        if has("basketball") { return .basketball }
        if has("soccer") { return .soccer }
        if has("tennis", "pickleball", "padel", "badminton", "squash", "racquet", "racket") { return .racquet }
        if has("kayak", "paddl", "canoe", "stand_up") { return .paddle }
        if has("hik") { return .hike }
        if has("yoga") { return .yoga }
        if has("golf") { return .golf }
        return nil
    }

    /// One recorded session of a sport.
    public struct Session: Sendable, Equatable {
        public let sport: Sport
        public let minutes: Int
        public let start: Date
        public init(sport: Sport, minutes: Int, start: Date) {
            self.sport = sport
            self.minutes = minutes
            self.start = start
        }
    }

    /// The skill facts every sport session adds up to.
    public static func facts(_ sessions: [Session], now: Date = .now) -> SkillFacts {
        var facts: SkillFacts = [:]
        for session in sessions { facts[session.sport.minutes, default: 0] += session.minutes }
        let volleyball = sessions.filter { $0.sport == .volleyball }
        let monthAgo = now.addingTimeInterval(-30 * 86_400)
        facts[.volleyballSessions] = volleyball.count
        facts[.volleyballLongest] = volleyball.map(\.minutes).max() ?? 0
        facts[.volleyballRecent] = volleyball.filter { $0.start >= monthAgo }.count
        return facts
    }
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
    /// The skill this one branches from, by id, for a skill tree. Nil for a root.
    public let parent: String?
    /// A name for each level ("Rookie", "Regular"…), shown next to "Lv. 3".
    public let ranks: [String]?

    public init(id: String, name: String, detail: String, measure: SkillMeasure, thresholds: [Int],
                glyph: String, rarity: Rarity, parent: String? = nil, ranks: [String]? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.measure = measure
        self.thresholds = thresholds
        self.glyph = glyph
        self.rarity = rarity
        self.parent = parent
        self.ranks = ranks
    }

    /// The name of the level reached, or nil when it has none or is locked.
    public func rank(_ facts: SkillFacts) -> String? {
        let level = level(facts)
        guard level > 0, let ranks, level <= ranks.count else { return nil }
        return ranks[level - 1]
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
        /// Minutes played: 1 h, 3 h, 6 h, 10 h, 20 h, 30 h, 50 h, 80 h, 120 h, 200 h.
        public static let sport = [60, 180, 360, 600, 1200, 1800, 3000, 4800, 7200, 12000]
    }

    /// Level names for sports, from first game to the top.
    public static let sportRanks = ["Beginner", "Rookie", "Regular", "Skilled", "Advanced",
                                    "Expert", "Elite", "Master", "Legend", "Mythic"]

    private static func sport(_ id: String, _ name: String, _ what: String, _ sport: Sport, _ glyph: String) -> SkillDefinition {
        SkillDefinition(id: id, name: name, detail: what, measure: sport.minutes, thresholds: Curve.sport,
                        glyph: glyph, rarity: .rare, ranks: sportRanks)
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
        // Workouts in Apple Health (Garmin and other watches sync into it).
        skill("trainingRegimen", "Training Regimen", "Every workout in Apple Health.", .workouts, Curve.volume, "dumbbell", .rare),
        skill("ironWheels", "Iron Wheels", "Cycling workouts.", .cyclingWorkouts, Curve.habit, "bolt", .common),
        skill("openWater", "Open Water", "Swimming workouts.", .swimWorkouts, Curve.habit, "moon", .common),
        skill("rhythm", "Rhythm", "Dance workouts.", .danceWorkouts, Curve.habit, "star", .common),
        skill("wayOfTheFist", "Way of the Fist", "Martial arts, boxing and wrestling workouts.", .martialArtsWorkouts, Curve.habit, "sword", .rare),
        // Sports: hours played, from Garmin and Apple Health. Each says what you can do.
        sport("volleyball", "Volleyball", "Hours on the court.", .volleyball, "ball"),
        SkillDefinition(id: "courtRegular", name: "Court Regular", detail: "Volleyball games played.",
                        measure: .volleyballSessions, thresholds: Curve.habit, glyph: "ball", rarity: .rare, parent: "volleyball"),
        SkillDefinition(id: "endlessRally", name: "Endless Rally", detail: "Your longest volleyball game, in minutes.",
                        measure: .volleyballLongest, thresholds: [45, 60, 90, 120, 150, 180], glyph: "hourglass",
                        rarity: .epic, parent: "volleyball"),
        SkillDefinition(id: "inSeason", name: "In Season", detail: "Volleyball games in the last 30 days.",
                        measure: .volleyballRecent, thresholds: [2, 4, 6, 8, 12, 16], glyph: "flame", rarity: .epic,
                        parent: "volleyball"),
        sport("waveRider", "Wave Rider", "Hours surfing.", .surf, "wave"),
        sport("rollingStone", "Rolling Stone", "Hours skating and skateboarding.", .skate, "bolt"),
        sport("powderHound", "Powder Hound", "Hours snowboarding.", .snowboard, "mountain"),
        sport("slopeRunner", "Slope Runner", "Hours skiing.", .ski, "mountain"),
        sport("wallWalker", "Wall Walker", "Hours climbing and bouldering.", .climb, "mountain"),
        sport("hoops", "Hoops", "Hours of basketball.", .basketball, "ball"),
        sport("pitchMaster", "Pitch Master", "Hours of football (soccer).", .soccer, "ball"),
        sport("racquetHand", "Racquet Hand", "Hours of tennis, padel, pickleball, badminton and squash.", .racquet, "ball"),
        sport("paddler", "Paddler", "Hours kayaking, canoeing and paddleboarding.", .paddle, "wave"),
        sport("trailFinder", "Trail Finder", "Hours hiking.", .hike, "mountain"),
        sport("flowState", "Flow State", "Hours of yoga.", .yoga, "moon"),
        sport("fairway", "Fairway", "Hours of golf.", .golf, "target"),
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

/// Skills in the order a list shows them: each root, then its branches.
public enum SkillTree {
    public struct Item: Sendable, Equatable {
        public let skill: SkillDefinition
        public let isBranch: Bool
    }

    /// Roots unlocked first, then by how close the rest are; a branch always
    /// follows its root, ordered the same way.
    public static func ordered(_ skills: [SkillDefinition], facts: SkillFacts) -> [Item] {
        func before(_ a: SkillDefinition, _ b: SkillDefinition) -> Bool {
            (a.level(facts), a.progress(facts)) > (b.level(facts), b.progress(facts))
        }
        let ids = Set(skills.map(\.id))
        // A branch whose root is missing is shown as a root, so it never disappears.
        let roots = skills.filter { $0.parent.map { !ids.contains($0) } ?? true }.sorted(by: before)
        return roots.flatMap { root in
            [Item(skill: root, isBranch: false)]
                + skills.filter { $0.parent == root.id }.sorted(by: before).map { Item(skill: $0, isBranch: true) }
        }
    }
}
