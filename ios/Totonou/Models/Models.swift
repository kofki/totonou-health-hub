import Foundation
import SwiftData
import TotonouCore

// SwiftData models. Each `@Model` class becomes a table; each stored property a column.
// Enums are stored as their raw String (`statRaw`) with a typed accessor (`stat`) on top,
// which keeps the store simple to migrate later.

/// Where the proof that a quest is done comes from.
enum QuestSource: String, CaseIterable {
    case manual, garmin, health, calendar, reminders

    var name: String {
        switch self {
        case .manual: "Manual"
        case .garmin: "Garmin"
        case .health: "Health"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
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
    /// "skill:level" for each skill already celebrated, so each level-up shows once.
    var skillLevelsRaw: [String] = []
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
    var nightQuests: Int = 0
    var onTimeQuests: Int = 0
    var longQuests: Int = 0
    var hardQuests: Int = 0
    var runQuests: Int = 0
    var stepQuests: Int = 0
    var mindfulQuests: Int = 0
    var calendarQuests: Int = 0
    var reminderQuests: Int = 0
    /// All-time workout counts from Apple Health, refreshed on every sync.
    var workouts: Int = 0
    var cyclingWorkouts: Int = 0
    var swimWorkouts: Int = 0
    var danceWorkouts: Int = 0
    var martialArtsWorkouts: Int = 0

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

    func skillFacts(on date: Date = .now) -> SkillFacts {
        [.strength: strength, .endurance: endurance, .intellect: intellect, .discipline: discipline,
         .recovery: recovery, .earlyQuests: earlyQuests, .nightQuests: nightQuests, .onTimeQuests: onTimeQuests,
         .longQuests: longQuests, .hardQuests: hardQuests, .mustDoDone: mustDoDone, .recoveries: recoveries,
         .bossesDefeated: bossesDefeated, .clearDays: clearDays.count, .streak: streak(on: date),
         .autoDone: autoDone, .runQuests: runQuests, .stepQuests: stepQuests, .mindfulQuests: mindfulQuests,
         .calendarQuests: calendarQuests, .reminderQuests: reminderQuests,
         .workouts: workouts, .cyclingWorkouts: cyclingWorkouts, .swimWorkouts: swimWorkouts,
         .danceWorkouts: danceWorkouts, .martialArtsWorkouts: martialArtsWorkouts]
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
    /// The calendar event or reminder this quest came from, if any.
    var externalID: String?
    /// The AlarmKit alarm that rings before this quest, if one is set.
    var alarmID: String?
    /// The objective this quest counts toward: finishing it adds one to that
    /// objective's tally for the day or week. Optional with a default, so a
    /// store saved by an older build opens unchanged.
    var objective: Objective? = nil
    /// The quest this one is a step of. Each step pays its own reward; the
    /// quest above it can only be finished once every step is done.
    var parent: Quest? = nil
    /// The steps of this quest. Deleting the quest deletes its steps.
    @Relationship(deleteRule: .cascade, inverse: \Quest.parent)
    var subquests: [Quest] = []

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

    /// Steps in the order they were planned.
    var orderedSubquests: [Quest] { subquests.sorted { ($0.scheduledAt, $0.title) < ($1.scheduledAt, $1.title) } }
    var subquestsDone: Int { subquests.filter(\.isDone).count }
    /// True while a step is still open: the quest waits for its steps.
    var isBlocked: Bool { subquests.contains { $0.isOpen } }
    /// The next step to do, or nil when there is none left.
    var nextStep: Quest? { orderedSubquests.first(where: \.isOpen) }
}

/// How often an objective's count starts again from zero.
enum ObjectivePeriod: String, CaseIterable, Sendable {
    /// Every day: "3 meals with 30 g of protein".
    case day
    /// Every week, Monday to Sunday: "4 strength sessions".
    case week
    /// Once, across the whole arc: "Publish 12 posts".
    case arc

    /// "today", "this week", "in total": how the count is read out.
    var phrase: String {
        switch self {
        case .day: "today"
        case .week: "this week"
        case .arc: "in total"
        }
    }

    /// "a day", "a week", "": how the target is read out.
    var rate: String {
        switch self {
        case .day: "a day"
        case .week: "a week"
        case .arc: "in total"
        }
    }

    /// The stretch of time that counts right now. Weeks start on Monday,
    /// whatever the phone's region, so "this week" means the same everywhere.
    func window(containing date: Date, arc: Arc?) -> DateInterval {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        case .arc:
            let start = arc.map { calendar.startOfDay(for: $0.startDate) } ?? .distantPast
            return DateInterval(start: min(start, date), end: .distantFuture)
        }
    }
}

/// A measurable target inside an arc: something to reach every day, every
/// week, or once over the whole arc. Quests are its steps: each finished quest
/// linked to it counts one toward the target.
///
/// "Train four days a week" is a wish. "Strength session, 4 a week", with a
/// 45-minute quest on Monday, Wednesday, Friday and Saturday, is an objective.
@Model
final class Objective {
    var title: String
    var periodRaw: String
    /// How many linked quests make it done for one period.
    var target: Int
    /// Optional detail: what counts, the standard to hit ("RPE 8, log the weights").
    var detail: String
    /// Position in the arc, so objectives keep the order they were made in.
    var order: Int
    var createdAt: Date
    var arc: Arc?

    @Relationship(deleteRule: .nullify, inverse: \Quest.objective)
    var quests: [Quest] = []

    init(title: String, period: ObjectivePeriod, target: Int, detail: String = "", order: Int = 0,
         arc: Arc? = nil, createdAt: Date = .now) {
        self.title = title
        self.periodRaw = period.rawValue
        self.target = max(target, 1)
        self.detail = detail
        self.order = order
        self.arc = arc
        self.createdAt = createdAt
    }

    var period: ObjectivePeriod { ObjectivePeriod(rawValue: periodRaw) ?? .week }

    /// Linked quests finished in the period that contains `date`.
    func done(on date: Date = .now) -> Int {
        let window = period.window(containing: date, arc: arc)
        return quests.filter { quest in
            guard let finished = quest.completedAt else { return false }
            return window.contains(finished)
        }.count
    }

    /// Linked quests still open in the same period: what is planned toward it.
    func planned(on date: Date = .now) -> Int {
        let window = period.window(containing: date, arc: arc)
        return quests.filter { $0.isOpen && window.contains($0.scheduledAt) }.count
    }

    func isMet(on date: Date = .now) -> Bool { done(on: date) >= target }

    /// 0...1, for a bar.
    func fraction(on date: Date = .now) -> Double { min(Double(done(on: date)) / Double(target), 1) }

    /// "2 of 4 this week".
    func label(on date: Date = .now) -> String { "\(done(on: date)) of \(target) \(period.phrase)" }
}

/// What makes an arc end.
enum ArcKind: String, CaseIterable {
    /// A stretch of time, like a Winter Arc. It ends on its end date.
    case seasonal
    /// One objective or change. It has no end date: it ends when you reach it.
    case objective

    var name: String {
        switch self {
        case .seasonal: "Season"
        case .objective: "Objective"
        }
    }

    var glyph: Glyph {
        switch self {
        case .seasonal: .hourglass
        case .objective: .target
        }
    }
}

/// How far an arc has come, counted from what is in the database. Never stored:
/// it is worked out fresh each time, so it cannot drift from the real data.
struct ArcProgress {
    /// Goals you ticked, out of the arc's goals.
    var goalsDone = 0
    var goals = 0
    /// Quests of this arc you finished, out of those that have come due.
    var questsDone = 0
    var questsDue = 0
    /// Boss tasks finished, out of all the tasks of this arc's bosses.
    var tasksDone = 0
    var tasks = 0
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
    /// When you ended the arc before its last day. Nil for an arc that is still
    /// running or that ran its full length. Optional with a default, so a store
    /// saved by an older build opens unchanged (see the note on `Player`).
    var endedAt: Date? = nil
    /// `ArcKind` raw value. Arcs saved before kinds existed are seasonal.
    var kindRaw: String = ArcKind.seasonal.rawValue
    /// The goals (by their text in `goals`) that you have ticked as reached.
    var goalsDone: [String] = []

    @Relationship(deleteRule: .nullify, inverse: \Quest.arc)
    var quests: [Quest] = []

    @Relationship(deleteRule: .cascade, inverse: \Boss.arc)
    var bosses: [Boss] = []

    /// The arc's measurable targets. `goals` above are the outcomes in words
    /// ("Bench 100 kg"); objectives are the daily and weekly counts that get you there.
    @Relationship(deleteRule: .cascade, inverse: \Objective.arc)
    var objectives: [Objective] = []

    /// Relationships have no guaranteed order, so sort before showing.
    var orderedObjectives: [Objective] { objectives.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) } }

    /// The objective with this title, ignoring case: how plans and Claude refer to one.
    func objective(named title: String?) -> Objective? {
        guard let title = title?.trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }
        return objectives.first { $0.title.compare(title, options: .caseInsensitive) == .orderedSame }
    }

    /// An objective arc has no end date; pass `.distantFuture` as its `endDate`.
    init(title: String, kanji: String, manifesto: String, goals: [String], startDate: Date, endDate: Date,
         kind: ArcKind = .seasonal) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.kanji = kanji
        self.manifesto = manifesto
        self.goals = goals
        self.startDate = startDate
        self.endDate = endDate
    }

    var plan: [QuestIdea] { questPlan.compactMap(QuestIdea.init(line:)) }

    /// Several arcs can run at once. One is active from the day it starts until
    /// its end date, unless you ended it early.
    func isActive(on date: Date = .now) -> Bool {
        endedAt == nil && date >= Calendar.current.startOfDay(for: startDate) && date < endDate
    }

    /// The moment the arc stopped counting: when you ended it, or its planned end.
    var closedAt: Date { endedAt ?? endDate }

    var kind: ArcKind { ArcKind(rawValue: kindRaw) ?? .seasonal }

    func isDone(_ goal: String) -> Bool { goalsDone.contains(goal) }
    var allGoalsDone: Bool { !goals.isEmpty && goals.allSatisfy(isDone) }

    /// True for an arc that is over and went the distance: a season that ran to
    /// its end date, or any arc closed with every goal ticked.
    var isCompleted: Bool {
        guard !isActive() else { return false }
        return endedAt == nil || allGoalsDone
    }

    func progress(on date: Date = .now) -> ArcProgress {
        // Recovery quests are a way out of a penalty, not part of the arc's work.
        let due = quests.filter { !$0.isRecovery && ($0.isDone || $0.scheduledAt <= date) }
        let tasks = bosses.flatMap(\.tasks)
        return ArcProgress(goalsDone: goals.filter(isDone).count, goals: goals.count,
                           questsDone: due.filter(\.isDone).count, questsDue: due.count,
                           tasksDone: tasks.filter(\.isDone).count, tasks: tasks.count)
    }

    /// The arc's one bar, 0...1. A season fills with time; an objective fills as
    /// its goals are ticked.
    func fraction(on date: Date = .now) -> Double {
        switch kind {
        case .seasonal:
            return Double(min(day(on: isActive(on: date) ? date : closedAt), totalDays)) / Double(totalDays)
        case .objective:
            return goals.isEmpty ? 0 : Double(goals.filter(isDone).count) / Double(goals.count)
        }
    }

    /// "Day 3 of 90" for a season, "Day 3" for an objective. A finished arc stays on its last day.
    func dayLabel(on date: Date = .now) -> String {
        let day = day(on: isActive(on: date) ? date : closedAt)
        switch kind {
        case .seasonal: return "Day \(min(day, totalDays)) of \(totalDays)"
        case .objective: return "Day \(day)"
        }
    }

    func day(on date: Date = .now) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: date).day ?? 0
        return max(days + 1, 1)
    }

    var totalDays: Int {
        // From the start of the first day, so an arc begun at 22:00 still has all 90 days.
        max(Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: endDate).day ?? 1, 1)
    }
}

// An extension with a `where` clause adds these to any list of arcs (an array,
// a @Query result) and to nothing else.
extension Sequence where Element == Arc {
    /// The arcs running on `date`, in the order they came in.
    func active(on date: Date = .now) -> [Arc] { filter { $0.isActive(on: date) } }

    /// Every active arc's daily quests as one list (see Exercise 16).
    func dailyPlan(on date: Date = .now) -> [QuestIdea] {
        // Only the quests planned for that weekday.
        PlanMerger.merged(active(on: date).map { $0.plan.filter { $0.runs(on: date) } })
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
