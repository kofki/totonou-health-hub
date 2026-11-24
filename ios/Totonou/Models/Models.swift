import Foundation
import SwiftData
import TotonouCore

// SwiftData models. Each `@Model` class becomes a table; each stored property a column.
// Enums are stored as their raw String (`statRaw`) with a typed accessor (`stat`) on top,
// which keeps the store simple to migrate later.

/// Where the proof that a quest is done comes from.
enum QuestSource: String, CaseIterable {
    case manual, garmin, health, calendar

    var name: String {
        switch self {
        case .manual: "Manual"
        case .garmin: "Garmin"
        case .health: "Health"
        case .calendar: "Calendar"
        }
    }
}

@Model
final class Player {
    var name: String
    var totalXP: Int
    var strength: Int
    var endurance: Int
    var intellect: Int
    var discipline: Int
    var recovery: Int
    /// Earned social-app minutes that have not been spent yet.
    var bankedMinutes: Int
    /// Start-of-day dates on which at least one quest was completed.
    var completionDays: [Date]

    // Rewards. Every new property has a default value: that is what lets
    // SwiftData upgrade an existing store on its own ("lightweight migration")
    // instead of failing to open data saved by an older build.

    /// Level-up points waiting to be put into a stat.
    var unspentStatPoints: Int = 0
    /// Each one saves the streak on one missed day. At most `Rewards.maxFreezes`.
    var streakFreezes: Int = 0
    /// Days a freeze was spent on. They count as completion days for the streak.
    var frozenDays: [Date] = []
    /// Short unlocks that work even during a penalty. Earned at rank-ups.
    var emergencyPasses: Int = 1
    /// When each pass was used, so escapes are on the record.
    var passLog: [Date] = []
    var titles: [String] = []
    var activeTitle: String?
    /// `Achievement` raw values.
    var achievementsRaw: [String] = []
    /// Streak milestones already opened during the current streak.
    var claimedMilestones: [Int] = []
    /// The last day the daily clear bonus was paid.
    var lastClearDay: Date?
    /// Days on which every quest was cleared.
    var clearDays: [Date] = []
    var lastLevelUpAt: Date?

    // Lifetime counts that achievements are judged on.
    var questsDone: Int = 0
    var autoDone: Int = 0
    var bossesDefeated: Int = 0
    var recoveries: Int = 0
    var earlyQuests: Int = 0
    var mustDoDone: Int = 0

    init(name: String, totalXP: Int = 0, strength: Int = 0, endurance: Int = 0, intellect: Int = 0,
         discipline: Int = 0, recovery: Int = 0, bankedMinutes: Int = 0, completionDays: [Date] = []) {
        self.name = name
        self.totalXP = totalXP
        self.strength = strength
        self.endurance = endurance
        self.intellect = intellect
        self.discipline = discipline
        self.recovery = recovery
        self.bankedMinutes = bankedMinutes
        self.completionDays = completionDays
    }

    var progress: LevelProgress { LevelCurve.progress(forTotalXP: totalXP) }

    var achievements: Set<Achievement> { Set(achievementsRaw.compactMap(Achievement.init(rawValue:))) }

    /// The streak, counting days saved by a freeze.
    func streak(on date: Date = .now) -> Int {
        StreakCalculator.currentStreak(completionDays: completionDays + frozenDays, today: date)
    }

    /// How many days in a row every quest was cleared.
    func clearStreak(on date: Date = .now) -> Int {
        StreakCalculator.currentStreak(completionDays: clearDays, today: date)
    }

    func facts(on date: Date = .now) -> AchievementFacts {
        AchievementFacts(questsDone: questsDone, autoDone: autoDone, bossesDefeated: bossesDefeated,
                         recoveries: recoveries, streak: streak(on: date), clearStreak: clearStreak(on: date),
                         earlyQuests: earlyQuests, mustDoDone: mustDoDone, level: progress.level)
    }

    func value(for stat: Stat) -> Int {
        switch stat {
        case .strength: strength
        case .endurance: endurance
        case .intellect: intellect
        case .discipline: discipline
        case .recovery: recovery
        }
    }

    func add(_ points: Int, to stat: Stat) {
        switch stat {
        case .strength: strength += points
        case .endurance: endurance += points
        case .intellect: intellect += points
        case .discipline: discipline += points
        case .recovery: recovery += points
        }
    }
}

@Model
final class Quest {
    var title: String
    var statRaw: String
    var rankRaw: String
    var sourceRaw: String
    /// Missing a critical quest sends you to the penalty zone.
    var isCritical: Bool
    /// A recovery quest is the way out of the penalty zone. It pays nothing.
    var isRecovery: Bool
    var scheduledAt: Date
    var durationMinutes: Int
    /// Which reading auto-completes this quest (see `SignalKey`), and the value it must reach.
    var signalKey: String?
    var target: Double?
    var completedAt: Date?
    var failedAt: Date?
    var autoCompleted: Bool
    var arc: Arc?

    init(title: String, stat: Stat, rank: Rank, source: QuestSource = .manual, isCritical: Bool = false,
         isRecovery: Bool = false, scheduledAt: Date, durationMinutes: Int = 15,
         signal: SignalKey? = nil, target: Double? = nil, arc: Arc? = nil) {
        self.title = title
        self.statRaw = stat.rawValue
        self.rankRaw = rank.rawValue
        self.sourceRaw = source.rawValue
        self.isCritical = isCritical
        self.isRecovery = isRecovery
        self.scheduledAt = scheduledAt
        self.durationMinutes = durationMinutes
        self.signalKey = signal?.rawValue
        self.target = target
        self.completedAt = nil
        self.failedAt = nil
        self.autoCompleted = false
        self.arc = arc
    }

    var stat: Stat { Stat(rawValue: statRaw) ?? .discipline }
    var rank: Rank { Rank(rawValue: rankRaw) ?? .e }
    var source: QuestSource { QuestSource(rawValue: sourceRaw) ?? .manual }
    var isDone: Bool { completedAt != nil }
    var isFailed: Bool { failedAt != nil }
    var isOpen: Bool { !isDone && !isFailed }
    var dueAt: Date { scheduledAt.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
}

/// A life chapter, written in your own words.
@Model
final class Arc {
    var title: String
    var kanji: String
    var manifesto: String
    var goals: [String]
    var startDate: Date
    var endDate: Date
    /// The daily quests this arc creates, one `QuestIdea.line` each. Empty for
    /// the seeded arc, which uses the built-in list.
    var questPlan: [String] = []

    @Relationship(deleteRule: .nullify, inverse: \Quest.arc)
    var quests: [Quest] = []

    @Relationship(deleteRule: .cascade, inverse: \Boss.arc)
    var bosses: [Boss] = []

    init(title: String, kanji: String, manifesto: String, goals: [String], startDate: Date, endDate: Date) {
        self.title = title
        self.kanji = kanji
        self.manifesto = manifesto
        self.goals = goals
        self.startDate = startDate
        self.endDate = endDate
    }

    var plan: [QuestIdea] { questPlan.compactMap(QuestIdea.init(line:)) }

    func day(on date: Date = .now) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: date).day ?? 0
        return max(days + 1, 1)
    }

    var totalDays: Int {
        max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
    }
}

/// A big deadline. Its HP is the subtasks you have not finished.
@Model
final class Boss {
    var name: String
    var deadline: Date
    var arc: Arc?

    @Relationship(deleteRule: .cascade, inverse: \BossTask.boss)
    var tasks: [BossTask] = []

    init(name: String, deadline: Date, arc: Arc? = nil) {
        self.name = name
        self.deadline = deadline
        self.arc = arc
    }

    /// Relationships have no guaranteed order, so sort before showing.
    var orderedTasks: [BossTask] { tasks.sorted { $0.order < $1.order } }
    var remaining: Int { tasks.filter { !$0.isDone }.count }
    var hp: Double { tasks.isEmpty ? 0 : Double(remaining) / Double(tasks.count) }
    var isDefeated: Bool { !tasks.isEmpty && remaining == 0 }
    var daysLeft: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: deadline).day ?? 0
    }
}

@Model
final class BossTask {
    var title: String
    var isDone: Bool
    var order: Int
    var boss: Boss?

    init(title: String, order: Int, isDone: Bool = false) {
        self.title = title
        self.order = order
        self.isDone = isDone
    }
}
