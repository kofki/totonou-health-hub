import Foundation
import Observation
import SwiftData
import TotonouCore
import WidgetKit

/// What a finished quest or a boss hit just paid. Shown as a banner by RootView.
struct RewardNotice: Identifiable, Equatable {
    let id = UUID()
    let xp: Int
    var stat: Stat?
    var points = 0
    var minutes = 0
}

/// A level-up, with what it paid and what earned it.
struct LevelUpEvent: Equatable {
    let from: Int
    let to: Int
    /// One per level crossed.
    let rewards: [LevelReward]
    /// "6 quests cleared", "2 finished from real data", "Strength +4 · Endurance +2".
    let evidence: [String]

    var isRankUp: Bool { rewards.contains(where: \.isRankUp) }
    var minutes: Int { rewards.reduce(0) { $0 + $1.minutes } }
    var statPoints: Int { rewards.reduce(0) { $0 + $1.statPoints } }
    var titles: [String] { rewards.compactMap(\.title) }
    var freezes: Int { rewards.reduce(0) { $0 + $1.freezes } }
    var passes: Int { rewards.reduce(0) { $0 + $1.passes } }
}

/// The end-of-day recap, shown once every quest of the day is cleared.
struct DayClearEvent: Equatable {
    let done: Int
    let minutes: Int
    let statLines: String
    let streak: Int
    let tomorrow: QuestIdea?
}

/// A moment big enough for a full-screen celebration. Shown one at a time.
struct Celebration: Identifiable, Equatable {
    enum Kind: Equatable {
        case levelUp(LevelUpEvent)
        case milestone(StreakMilestone)
        case achievement(Achievement)
        case dayClear(DayClearEvent)
        case freezeUsed(days: Int, streak: Int)
        case skill(Skill, level: Int)
    }

    let id = UUID()
    let kind: Kind
}

/// The game loop: completing quests, paying rewards, auto-completion, penalties.
/// Views never change XP or stats themselves — they ask the engine.
@MainActor
@Observable
final class QuestEngine {
    /// Waiting celebrations, oldest first. The root view shows the first one.
    private(set) var celebrations: [Celebration] = []
    var celebration: Celebration? { celebrations.first }

    func dismissCelebration() {
        if !celebrations.isEmpty { celebrations.removeFirst() }
    }

    #if DEBUG
    /// Debug builds only, with the launch argument -previewCelebrations: queue one
    /// of every celebration so their screens can be checked. Nothing is saved:
    /// these are screens, not progress.
    func previewCelebrations() {
        celebrations = [
            .init(kind: .levelUp(LevelUpEvent(from: 19, to: 20, rewards: Rewards.rewards(from: 19, to: 20),
                                              evidence: ["6 quests cleared", "2 finished from real data", "Strength +4 · Endurance +2"]))),
            .init(kind: .skill(.ironBody, level: 1)),
            .init(kind: .achievement(.streak7)),
            .init(kind: .milestone(StreakMilestones.all[1])),
            .init(kind: .freezeUsed(days: 1, streak: 8)),
            .init(kind: .dayClear(DayClearEvent(done: 4, minutes: 65, statLines: "Strength +4 · Intellect +3",
                                                streak: 8, tomorrow: QuestIdea(title: "Run 5 km easy", stat: .endurance, hour: 7)))),
        ]
    }
    #endif

    /// Set whenever something pays out. The root view clears it after a moment.
    var notice: RewardNotice?
    var isSyncing = false
    var lastSync: Date?
    /// Today's Health readings from the last sync, for quest progress bars.
    private(set) var readings: [SignalKey: Double] = [:]

    /// One must-do quest per day: missing it sends you to the penalty zone.
    /// Turning one on turns the others for today off.
    func setMustDo(_ on: Bool, quest: Quest, todays: [Quest]) {
        guard quest.isOpen, !quest.isRecovery else { return }
        if on { for other in todays where other !== quest && other.isOpen { other.isCritical = false } }
        quest.isCritical = on
    }

    /// Where the cloud backup stands. Shown on the Status screen.
    var cloudState: CloudState

    /// Whether quest reminders are switched on. Remembered between launches.
    private(set) var remindersOn = UserDefaults.standard.bool(forKey: "remindersOn")

    private let signals: any SignalSource
    private let cloud: any CloudStore
    private let reminders: any Reminders
    /// Calendar events and Apple Reminders.
    let day: any DaySource
    let alarms: any QuestAlarms

    /// The daily wake-up alarm, remembered between launches.
    private(set) var wakeAlarmID = UserDefaults.standard.string(forKey: "wakeAlarmID")

    init(signals: any SignalSource = HealthKitSignalSource(), cloud: any CloudStore = MockCloudStore(),
         reminders: any Reminders = LocalReminders(), day: any DaySource = EventKitDaySource.shared,
         alarms: (any QuestAlarms)? = nil) {
        self.signals = signals
        self.cloud = cloud
        self.reminders = reminders
        self.day = day
        // Built here, not as a default argument: defaults run outside the main actor.
        self.alarms = alarms ?? Alarms.make()
        self.cloudState = cloud is MockCloudStore ? .local : .syncing
    }

    // MARK: Alarms

    /// An alarm 10 minutes before a quest starts (or at its start, if that is closer).
    func setAlarm(_ on: Bool, for quest: Quest, now: Date = .now) async {
        if let id = quest.alarmID { alarms.cancel(id: id); quest.alarmID = nil }
        guard on, quest.isOpen else { return }
        let early = quest.scheduledAt.addingTimeInterval(-10 * 60)
        let at = early > now ? early : quest.scheduledAt
        guard at > now else { return }
        quest.alarmID = await alarms.schedule(title: quest.title, at: at)
    }

    /// A daily alarm 10 minutes before the arc's first quest of the day.
    func setWakeAlarm(_ on: Bool, plan: [QuestIdea]) async {
        if let id = wakeAlarmID { alarms.cancel(id: id) }
        wakeAlarmID = nil
        if on, let first = plan.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) {
            let total = first.hour * 60 + first.minute - 10
            wakeAlarmID = await alarms.scheduleDaily(title: first.title, hour: total / 60, minute: total % 60)
        }
        UserDefaults.standard.set(wakeAlarmID, forKey: "wakeAlarmID")
    }

    // MARK: Widget

    /// Hand the widget the next quest, level and streak, then ask it to redraw.
    func publishWidget(player: Player, quests: [Quest], now: Date = .now) {
        let next = quests.filter { $0.isOpen && $0.dueAt > now }.min { $0.scheduledAt < $1.scheduledAt }
        let snapshot = WidgetSnapshot(
            questTitle: next?.title ?? (quests.isEmpty ? "No quests yet" : "All clear"),
            questTime: next?.scheduledAt.clock ?? "",
            questRank: next?.rank ?? .e,
            streak: player.streak(on: now),
            level: player.progress.level,
            word: WordBook.word(for: now)
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Calendar and Reminders

    /// Reminders due today (or overdue) become quests, once each. A reminder
    /// ticked off in the Reminders app completes its quest here too.
    func importReminders(context: ModelContext, player: Player, now: Date = .now) async {
        guard day.hasRemindersAccess else { return }
        let due = await day.remindersDue(by: now)
        let source = QuestSource.reminders.rawValue
        let existing = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.sourceRaw == source }))) ?? []
        let known = Set(existing.compactMap(\.externalID))
        let calendar = Calendar.current
        for reminder in due where !known.contains(reminder.id) {
            // Overdue reminders land on today; ones without a time go to the next half hour.
            var at = reminder.due ?? now.addingTimeInterval(30 * 60)
            if !calendar.isDate(at, inSameDayAs: now) { at = now.addingTimeInterval(30 * 60) }
            let quest = Quest(title: reminder.title, stat: .discipline, rank: .e, source: .reminders,
                              scheduledAt: at, durationMinutes: 15)
            quest.externalID = reminder.id
            context.insert(quest)
        }
        for quest in existing where quest.isOpen {
            guard let id = quest.externalID else { continue }
            if day.isReminderCompleted(id: id) == true { complete(quest, player: player, auto: true, now: now) }
        }
    }

    /// Turn a calendar event into a quest at the same time.
    func addQuest(from event: CalendarEventInfo, stat: Stat = .discipline, context: ModelContext) {
        let minutes = max(5, Int(event.end.timeIntervalSince(event.start) / 60))
        let quest = Quest(title: event.title, stat: stat, rank: minutes >= 60 ? .c : .d, source: .calendar,
                          scheduledAt: event.start, durationMinutes: min(minutes, 240))
        quest.externalID = event.id
        context.insert(quest)
    }

    // MARK: Cloud backup

    private var hasRestored = false

    /// Copy the player and today's quests to the cloud. The first time it runs
    /// it also looks for a cloud profile that is further along and adopts it.
    func backUp(player: Player, quests: [Quest]) async {
        guard !(cloud is MockCloudStore) else { return }
        cloudState = .syncing
        do {
            try await cloud.connect()
            if !hasRestored {
                hasRestored = true
                if let remote = try await cloud.loadProfile(), remote.totalXP > player.totalXP {
                    player.apply(remote)
                }
            }
            // Records are plain values, so they can leave the main actor safely;
            // the SwiftData objects themselves cannot.
            try await cloud.save(profile: player.record)
            try await cloud.save(quests: quests.map(\.record))
            cloudState = .synced(.now)
        } catch is CancellationError {
            // A newer backup replaced this one.
        } catch {
            cloudState = .failed(error.localizedDescription)
        }
    }

    // MARK: Reminders

    /// Turning reminders on asks iOS for permission the first time.
    func setReminders(_ on: Bool, quests: [Quest], plan: [QuestIdea]) async {
        remindersOn = on ? await reminders.requestPermission() : false
        UserDefaults.standard.set(remindersOn, forKey: "remindersOn")
        if remindersOn { await refreshReminders(quests: quests, plan: plan) } else { await reminders.schedule([]) }
    }

    /// One notification per open quest today, plus the arc's quests for the next
    /// three days, so reminders keep coming even if you do not open the app.
    func refreshReminders(quests: [Quest], plan: [QuestIdea], now: Date = .now) async {
        guard remindersOn else { return }
        let calendar = Calendar.current
        var items = quests.filter { $0.isOpen && $0.scheduledAt > now }.map {
            ReminderItem(id: "today-\($0.title)", title: $0.title,
                         body: "+\($0.rank.xp) XP · +\($0.rank.earnedMinutes) min", at: $0.scheduledAt)
        }
        for offset in 1...3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            for idea in plan {
                guard let at = calendar.date(bySettingHour: idea.hour, minute: idea.minute, second: 0, of: day) else { continue }
                items.append(ReminderItem(id: "day\(offset)-\(idea.title)", title: idea.title,
                                          body: "+\(idea.rank.xp) XP · +\(idea.rank.earnedMinutes) min", at: at))
            }
        }
        await reminders.schedule(items)
    }

    // MARK: Adding

    /// Put one more quest on today's list. If its time has passed, it is due in half an hour.
    func add(_ idea: QuestIdea, arc: Arc?, context: ModelContext, now: Date = .now) {
        let quest = QuestPlanner.quests(from: [idea], on: now, arc: arc)[0]
        if quest.scheduledAt < now { quest.scheduledAt = now.addingTimeInterval(30 * 60) }
        context.insert(quest)
    }

    // MARK: Completing

    func complete(_ quest: Quest, player: Player, auto: Bool = false, now: Date = .now) {
        guard quest.isOpen else { return }
        quest.completedAt = now
        quest.autoCompleted = auto
        Sounds.play(.complete)
        // Keep Apple Reminders in step: done here means done there.
        if quest.source == .reminders, let id = quest.externalID { day.completeReminder(id: id) }
        // A finished quest needs no alarm.
        if let id = quest.alarmID { alarms.cancel(id: id); quest.alarmID = nil }
        if quest.isRecovery {
            player.recoveries += 1
        } else {
            // Mastery: the stat's value before this quest decides the bonus.
            let xp = Rewards.questXP(rank: quest.rank, statValue: player.value(for: quest.stat))
            player.add(quest.rank.statPoints, to: quest.stat)
            player.bankedMinutes += quest.rank.earnedMinutes
            player.questsDone += 1
            if auto { player.autoDone += 1 }
            if quest.isCritical { player.mustDoDone += 1 }
            let clock = Calendar.current.dateComponents([.hour, .minute], from: now)
            if (clock.hour ?? 12) * 60 + (clock.minute ?? 0) < 6 * 60 + 30 { player.earlyQuests += 1 }
            reward(player, xp: xp, context: quest.modelContext, now: now)
            notice = RewardNotice(xp: xp, stat: quest.stat,
                                  points: quest.rank.statPoints, minutes: quest.rank.earnedMinutes)
        }
        let day = Calendar.current.startOfDay(for: now)
        if !player.completionDays.contains(day) {
            player.completionDays.append(day)
        }
        checkMilestone(player, now: now)
        checkAchievements(player, now: now)
        checkDayClear(player, context: quest.modelContext, arc: quest.arc, now: now)
    }

    /// Land a hit on a boss by finishing one of its subtasks.
    func strike(_ task: BossTask, player: Player, now: Date = .now) {
        guard !task.isDone else { return }
        task.isDone = true
        Sounds.play(.hit)
        player.add(1, to: .discipline)
        let defeated = task.boss?.isDefeated ?? false
        if defeated { player.bossesDefeated += 1 }
        reward(player, xp: defeated ? 300 : 25, context: task.modelContext, now: now)
        notice = RewardNotice(xp: defeated ? 300 : 25, stat: .discipline, points: 1)
        checkAchievements(player, now: now)
    }

    /// Adds XP and pays every level it crosses.
    private func reward(_ player: Player, xp: Int, context: ModelContext?, now: Date) {
        let before = player.progress.level
        player.totalXP += xp
        let after = player.progress.level
        guard after > before else { return }
        let rewards = Rewards.rewards(from: before, to: after)
        for reward in rewards {
            player.unspentStatPoints += reward.statPoints
            player.bankedMinutes += reward.minutes
            player.streakFreezes = min(Rewards.maxFreezes, player.streakFreezes + reward.freezes)
            player.emergencyPasses += reward.passes
            if let title = reward.title, !player.titles.contains(title) {
                player.titles.append(title)
                player.activeTitle = title
            }
        }
        let event = LevelUpEvent(from: before, to: after, rewards: rewards,
                                 evidence: evidence(since: player.lastLevelUpAt, context: context))
        player.lastLevelUpAt = now
        celebrations.append(Celebration(kind: .levelUp(event)))
        Sounds.play(.levelUp)
    }

    /// What earned a level: the quests finished since the last one.
    private func evidence(since: Date?, context: ModelContext?) -> [String] {
        guard let context else { return [] }
        let start = since ?? .distantPast
        let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.completedAt != nil && !$0.isRecovery })
        let done = ((try? context.fetch(descriptor)) ?? []).filter { ($0.completedAt ?? .distantPast) > start }
        guard !done.isEmpty else { return [] }
        var lines = ["\(done.count) quest\(done.count == 1 ? "" : "s") cleared"]
        let auto = done.filter(\.autoCompleted).count
        if auto > 0 { lines.append("\(auto) finished from real data") }
        lines.append(Self.statLine(for: done))
        return lines
    }

    /// "Strength +4 · Endurance +2", biggest first.
    static func statLine(for quests: [Quest]) -> String {
        var gains: [Stat: Int] = [:]
        for quest in quests { gains[quest.stat, default: 0] += quest.rank.statPoints }
        return gains.sorted { $0.value > $1.value }.prefix(3)
            .map { "\($0.key.title) +\($0.value)" }
            .joined(separator: " · ")
    }

    // MARK: Streaks, clears, achievements

    /// Spend freezes on missed days, and forget milestones of a streak that ended.
    /// Runs at launch and whenever the app comes back.
    func refreshStreak(player: Player, now: Date = .now) {
        let days = StreakFreeze.daysToFreeze(completionDays: player.completionDays, frozenDays: player.frozenDays,
                                             available: player.streakFreezes, today: now)
        if !days.isEmpty {
            player.frozenDays += days
            player.streakFreezes -= days.count
            celebrations.append(Celebration(kind: .freezeUsed(days: days.count, streak: player.streak(on: now))))
        }
        if player.streak(on: now) < (player.claimedMilestones.max() ?? 0) {
            player.claimedMilestones = []
        }
    }

    private func checkMilestone(_ player: Player, now: Date) {
        let streak = player.streak(on: now)
        if streak < (player.claimedMilestones.max() ?? 0) { player.claimedMilestones = [] }
        guard let milestone = StreakMilestones.reached(streak: streak),
              !player.claimedMilestones.contains(milestone.days) else { return }
        player.claimedMilestones.append(milestone.days)
        player.bankedMinutes += milestone.minutes
        player.streakFreezes = min(Rewards.maxFreezes, player.streakFreezes + milestone.freezes)
        celebrations.append(Celebration(kind: .milestone(milestone)))
    }

    private func checkAchievements(_ player: Player, now: Date) {
        let new = player.facts(on: now).earned.subtracting(player.achievements)
        for achievement in Achievement.allCases where new.contains(achievement) {
            player.achievementsRaw.append(achievement.rawValue)
            if !player.titles.contains(achievement.title) { player.titles.append(achievement.title) }
            celebrations.append(Celebration(kind: .achievement(achievement)))
        }
        checkSkills(player, now: now)
    }

    /// A skill unlocking or reaching a new level gets its own moment.
    private func checkSkills(_ player: Player, now: Date) {
        let facts = player.skillFacts(on: now)
        for skill in Skill.allCases {
            let level = skill.level(facts)
            let key = "\(skill.rawValue):\(level)"
            guard level > 0, !player.skillLevelsRaw.contains(key) else { continue }
            player.skillLevelsRaw.removeAll { $0.hasPrefix("\(skill.rawValue):") }
            player.skillLevelsRaw.append(key)
            celebrations.append(Celebration(kind: .skill(skill, level: level)))
        }
    }

    /// When the last quest of the day is done: pay the clear bonus and queue the recap.
    private func checkDayClear(_ player: Player, context: ModelContext?, arc: Arc?, now: Date) {
        guard let context else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard player.lastClearDay.map({ !calendar.isDate($0, inSameDayAs: now) }) ?? true,
              let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= start && $0.scheduledAt < end })
        let today = ((try? context.fetch(descriptor)) ?? []).filter { !$0.isRecovery }
        guard !today.isEmpty, today.allSatisfy(\.isDone) else { return }
        player.lastClearDay = start
        if !player.clearDays.contains(start) { player.clearDays.append(start) }
        player.bankedMinutes += Rewards.dailyClearMinutes
        reward(player, xp: Rewards.dailyClearXP, context: context, now: now)
        let earned = today.reduce(0) { $0 + $1.rank.earnedMinutes } + Rewards.dailyClearMinutes
        let tomorrow = arc?.plan.min { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        celebrations.append(Celebration(kind: .dayClear(DayClearEvent(
            done: today.count, minutes: earned, statLines: Self.statLine(for: today),
            streak: player.streak(on: now), tomorrow: tomorrow))))
        checkAchievements(player, now: now)
    }

    // MARK: Spending rewards

    func spendStatPoint(on stat: Stat, player: Player) {
        guard player.unspentStatPoints > 0 else { return }
        player.unspentStatPoints -= 1
        player.add(1, to: stat)
        checkSkills(player, now: .now)
    }

    func wear(_ title: String?, player: Player) {
        guard title == nil || player.titles.contains(title!) else { return }
        player.activeTitle = title
    }

    /// Spends one emergency pass. Returns false when none are left.
    @discardableResult
    func usePass(player: Player, now: Date = .now) -> Bool {
        guard player.emergencyPasses > 0 else { return false }
        player.emergencyPasses -= 1
        player.passLog.append(now)
        return true
    }

    // MARK: Auto-completion

    /// Pull the latest readings and complete every quest whose target is met.
    func sync(quests: [Quest], player: Player) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        guard let readings = try? await signals.latest() else { return }
        self.readings = readings
        for quest in quests where quest.isOpen {
            guard let raw = quest.signalKey, let key = SignalKey(rawValue: raw),
                  let target = quest.target, let value = readings[key] else { continue }
            if value >= target {
                complete(quest, player: player, auto: true)
            }
        }
        lastSync = .now
    }

    /// The same as pulling to refresh, for when Health wakes the app with no screen open.
    func syncInBackground(container: ModelContainer, now: Date = .now) async {
        // The main context belongs to the main actor, which this engine runs on.
        let context = container.mainContext
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start),
              let player = try? context.fetch(FetchDescriptor<Player>()).first else { return }
        let today = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= start && $0.scheduledAt < end }))) ?? []
        await sync(quests: today, player: player)
        try? context.save()
    }

    // MARK: Penalties

    /// A critical quest that ran past its end time is failed and replaced by a recovery quest.
    func enforcePenalties(quests: [Quest], context: ModelContext, now: Date = .now) {
        for quest in quests where quest.isCritical && quest.isOpen && quest.dueAt < now {
            quest.failedAt = now
            context.insert(Quest(
                title: "Recovery: 20 push-ups, 10 min walk",
                stat: .discipline, rank: .e, isRecovery: true,
                scheduledAt: now, durationMinutes: 15, arc: quest.arc
            ))
        }
    }

    /// True while a recovery quest is waiting. Everything stays sealed until it is done.
    func isLocked(_ quests: [Quest]) -> Bool {
        quests.contains { $0.isRecovery && $0.isOpen }
    }

    // MARK: Screen time

    func spend(minutes: Int, player: Player) {
        guard player.bankedMinutes >= minutes else { return }
        player.bankedMinutes -= minutes
    }
}
