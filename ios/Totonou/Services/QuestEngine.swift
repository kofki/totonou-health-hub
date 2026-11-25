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
        case skill(SkillDefinition, level: Int)
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
            .init(kind: .skill(SkillCatalog.builtIn[0], level: 1)),
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
    /// The last batch of Claude's changes applied (ClaudeChanges.swift).
    var claudeApplied: ClaudeActivity?
    /// True while Claude's changes are being applied. Launch and coming back to
    /// the app can both start it; a second run would apply the same changes twice.
    var isApplyingClaude = false
    /// The last snapshot sent to Claude, so an unchanged game is not uploaded again.
    var lastClaudeSnapshot: String?

    /// The skill catalogue: the Supabase `skills` table when it can be read,
    /// otherwise the list built into the app.
    private(set) var skills: [SkillDefinition] = SkillCatalog.builtIn

    func refreshSkills() async {
        guard !(cloud is MockCloudStore), let rows = try? await cloud.loadSkills() else { return }
        let usable = SkillCatalog.valid(rows)
        // The table wins for skills it has; skills added to the app since are kept.
        if !usable.isEmpty {
            let ids = Set(usable.map(\.id))
            skills = usable + SkillCatalog.builtIn.filter { !ids.contains($0.id) }
        }
    }

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
    /// Morning summary, evening count and must-do warnings (Nudges.swift).
    private(set) var dailyNudgesOn = UserDefaults.standard.bool(forKey: "dailyNudgesOn")
    /// Streak-at-risk and unspent stat point alerts (Nudges.swift).
    private(set) var streakAlertsOn = UserDefaults.standard.bool(forKey: "streakAlertsOn")

    private let signals: any SignalSource
    // Readable from the engine's extensions in other files (ProgressReset.swift);
    // only the engine sets it.
    let cloud: any CloudStore
    private let reminders: any Reminders
    /// Calendar events and Apple Reminders.
    let day: any DaySource
    let alarms: any QuestAlarms

    /// The daily wake-up alarm, remembered between launches.
    private(set) var wakeAlarmID = UserDefaults.standard.string(forKey: "wakeAlarmID")

    init(signals: any SignalSource = GarminSource(), cloud: any CloudStore = MockCloudStore(),
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

    /// A daily alarm 10 minutes before the first quest of the day.
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
    func backUp(player: Player, quests: [Quest], arcs: [Arc] = []) async {
        guard !(cloud is MockCloudStore) else { return }
        cloudState = .syncing
        do {
            try await cloud.connect()
            // After Reset progress, the cloud copy is the old progress until the
            // fresh one is saved: never restore from it in between.
            let resetPending = UserDefaults.standard.bool(forKey: ProgressReset.pendingKey)
            if !hasRestored && !resetPending {
                hasRestored = true
                if let remote = try await cloud.loadProfile(), remote.totalXP > player.totalXP {
                    player.apply(remote)
                }
            }
            // Records are plain values, so they can leave the main actor safely;
            // the SwiftData objects themselves cannot.
            try await cloud.save(profile: player.record)
            try await cloud.save(quests: quests.map(\.record))
            // Arcs only live on the phone otherwise; this is their backup.
            try await cloud.save(arcs: arcs.map(\.record))
            if resetPending { UserDefaults.standard.set(false, forKey: ProgressReset.pendingKey) }
            cloudState = .synced(.now)
        } catch is CancellationError {
            // A newer backup replaced this one.
        } catch {
            cloudState = .failed(error.localizedDescription)
        }
    }

    // MARK: Reminders

    /// Turning reminders on asks iOS for permission the first time.
    func setReminders(_ on: Bool, quests: [Quest], plan: [QuestIdea], player: Player? = nil, arcs: [Arc] = []) async {
        remindersOn = on ? await reminders.requestPermission() : false
        UserDefaults.standard.set(remindersOn, forKey: "remindersOn")
        await refreshReminders(quests: quests, plan: plan, player: player, arcs: arcs)
    }

    /// The daily nudges and the streak and reward alerts. Each asks iOS for
    /// permission the first time it is switched on.
    func setNudges(daily: Bool? = nil, streak: Bool? = nil, quests: [Quest], player: Player?, arcs: [Arc]) async {
        if let daily {
            dailyNudgesOn = daily ? await reminders.requestPermission() : false
            UserDefaults.standard.set(dailyNudgesOn, forKey: "dailyNudgesOn")
        }
        if let streak {
            streakAlertsOn = streak ? await reminders.requestPermission() : false
            UserDefaults.standard.set(streakAlertsOn, forKey: "streakAlertsOn")
        }
        await refreshReminders(quests: quests, plan: arcs.dailyPlan(), player: player, arcs: arcs)
    }

    /// One notification per open quest today, plus the arc's quests for the next
    /// three days, so reminders keep coming even if you do not open the app.
    func refreshReminders(quests: [Quest], plan: [QuestIdea], player: Player? = nil, arcs: [Arc] = [],
                          now: Date = .now) async {
        // Everything is rescheduled together, because scheduling replaces what was there.
        let settings = Nudges.Settings(daily: dailyNudgesOn, streakAndRewards: streakAlertsOn)
        var items = Nudges.items(quests: quests, player: player, arcs: arcs, settings: settings, now: now)
        guard remindersOn else {
            await reminders.schedule(items)
            return
        }
        let calendar = Calendar.current
        items += quests.filter { $0.isOpen && $0.scheduledAt > now }.map {
            ReminderItem(id: "today-\($0.title)", title: $0.title,
                         body: "+\($0.rank.xp) XP · +\($0.rank.earnedMinutes) min", at: $0.scheduledAt)
        }
        for offset in 1...3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            // Each day's own plan when the arcs are known, so weekday quests land on their days.
            for idea in arcs.isEmpty ? plan : arcs.dailyPlan(on: day) {
                guard let at = calendar.date(bySettingHour: idea.hour, minute: idea.minute, second: 0, of: day) else { continue }
                items.append(ReminderItem(id: "day\(offset)-\(idea.title)", title: idea.title,
                                          body: "+\(idea.rank.xp) XP · +\(idea.rank.earnedMinutes) min", at: at))
            }
        }
        await reminders.schedule(items)
    }

    // MARK: Adding

    /// Add a step to a quest. It pays its own reward, and the quest cannot be
    /// finished until every step is done. Steps sit just before the quest.
    @discardableResult
    func addStep(_ title: String, to quest: Quest, minutes: Int = 15, context: ModelContext) -> Quest? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, quest.isOpen, quest.parent == nil else { return nil }
        let step = Quest(title: title, stat: quest.stat, rank: minutes >= 30 ? .d : .e,
                         scheduledAt: quest.scheduledAt, durationMinutes: minutes, arc: quest.arc)
        step.objective = quest.objective
        // Steps share the quest's start; their order is the order they were added.
        step.scheduledAt = quest.scheduledAt.addingTimeInterval(Double(quest.subquests.count))
        context.insert(step)
        quest.subquests.append(step)
        return step
    }

    /// Put one more quest on today's list. If its time has passed, it is due in half an hour.
    func add(_ idea: QuestIdea, arc: Arc?, context: ModelContext, now: Date = .now) {
        let quest = QuestPlanner.quests(from: [idea], on: now, arc: arc)[0]
        if quest.scheduledAt < now { quest.scheduledAt = now.addingTimeInterval(30 * 60) }
        QuestPlanner.insert(quest, from: [idea], context: context)
    }

    // MARK: Arcs

    /// Let quests with this title, from any other arc, also count toward an
    /// objective (or stop them). It changes counting only: XP is paid once.
    func share(_ title: String, with objective: Objective, on: Bool) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        objective.sharedTitles.removeAll { $0.compare(title, options: .caseInsensitive) == .orderedSame }
        if on { objective.sharedTitles.append(title) }
    }

    /// Tick a goal as reached, or untick it. Only while the arc is running.
    func setGoal(_ goal: String, done: Bool, arc: Arc) {
        guard arc.isActive(), arc.goals.contains(goal) else { return }
        arc.goalsDone.removeAll { $0 == goal }
        if done { arc.goalsDone.append(goal) }
    }

    /// Run a finished arc again from today, with its goals, objectives and plan.
    /// A season gets a fresh 90 days; an objective has no end date again.
    /// Today's quests from its plan appear straight away.
    func restart(_ arc: Arc, context: ModelContext, now: Date = .now) {
        guard !arc.isActive(on: now) else { return }
        let calendar = Calendar.current
        arc.startDate = now
        arc.endDate = arc.kind == .seasonal
            ? calendar.date(byAdding: .day, value: 90, to: calendar.startOfDay(for: now))!
            : .distantFuture
        arc.endedAt = nil
        Bootstrap.rollDailyQuests(context, now: now)
    }

    /// Remove a finished arc for good: its objectives and bosses go with it.
    /// Its finished quests stay in your history, without an arc, and the XP
    /// they paid is kept. A running arc has to be ended first.
    func delete(_ arc: Arc, context: ModelContext, now: Date = .now) {
        guard !arc.isActive(on: now) else { return }
        for quest in arc.quests where quest.isOpen {
            if let id = quest.alarmID { alarms.cancel(id: id) }
            context.delete(quest)
        }
        context.delete(arc)
    }

    /// End an arc before its last day, or close an objective you have reached. Its unfinished quests leave Today; the
    /// ones you finished or missed stay as history, and other arcs are untouched.
    func end(_ arc: Arc, context: ModelContext, now: Date = .now) {
        guard arc.endedAt == nil else { return }
        arc.endedAt = now
        // A recovery quest stays: it is the only way out of the penalty zone.
        for quest in arc.quests where quest.isOpen && !quest.isRecovery {
            if let id = quest.alarmID { alarms.cancel(id: id) }
            context.delete(quest)
        }
    }

    // MARK: Completing

    func complete(_ quest: Quest, player: Player, auto: Bool = false, now: Date = .now) {
        // A quest with open steps waits for them (sub-quests are its requirements).
        guard quest.isOpen, !quest.isBlocked else { return }
        quest.completedAt = now
        quest.autoCompleted = auto
        Sounds.play(.complete)
        // Keep Apple Reminders in step: done here means done there.
        if quest.source == .reminders, let id = quest.externalID { day.completeReminder(id: id) }
        // A finished quest needs no alarm.
        if let id = quest.alarmID { alarms.cancel(id: id); quest.alarmID = nil }
        let damageBefore = player.damage
        if quest.isRecovery {
            player.recoveries += 1
            player.heal(HitPoints.healForRecovery)
            quest.hpHealed = damageBefore - player.damage
        } else {
            // Mastery: the stat's value before this quest decides the bonus.
            var xp = Rewards.questXP(rank: quest.rank, statValue: player.value(for: quest.stat))
            // Wounded or down: half XP. Finishing things is also how HP comes back.
            if player.condition != .healthy { xp /= 2 }
            player.heal(HitPoints.healForQuest(rank: quest.rank))
            healIfArcCleared(quest, player: player, now: now)
            // Everything this quest actually healed, the arc's clear bonus included.
            quest.hpHealed = damageBefore - player.damage
            quest.xpEarned = xp
            player.add(quest.rank.statPoints, to: quest.stat)
            player.bankedMinutes += quest.rank.earnedMinutes
            tally(quest, player: player, at: now, by: 1)
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
        checkDayClear(player, context: quest.modelContext, now: now)
    }

    /// The habit counters a finished quest adds to (and an untick takes back).
    private func tally(_ quest: Quest, player: Player, at time: Date, by step: Int) {
        func bump(_ value: inout Int) { value = max(value + step, 0) }
        bump(&player.questsDone)
        if quest.autoCompleted { bump(&player.autoDone) }
        if quest.isCritical { bump(&player.mustDoDone) }
        let clock = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minute = (clock.hour ?? 12) * 60 + (clock.minute ?? 0)
        if minute < 6 * 60 + 30 { bump(&player.earlyQuests) }
        if minute >= 21 * 60 { bump(&player.nightQuests) }
        if time <= quest.dueAt { bump(&player.onTimeQuests) }
        if quest.durationMinutes >= 60 { bump(&player.longQuests) }
        if quest.rank >= .a { bump(&player.hardQuests) }
        if quest.autoCompleted {
            switch quest.signalKey.flatMap(SignalKey.init(rawValue:)) {
            case .runKm: bump(&player.runQuests)
            case .steps: bump(&player.stepQuests)
            case .focusMinutes: bump(&player.mindfulQuests)
            default: break
            }
        }
        if quest.source == .calendar { bump(&player.calendarQuests) }
        if quest.source == .reminders { bump(&player.reminderQuests) }
    }

    /// Untick a finished quest: it is open again, and what finishing it paid
    /// (XP, stat points, minutes, HP, the arc's clear bonus) is taken back.
    /// Level-up rewards, titles and achievements already earned are kept.
    /// Unticking a step also unticks its finished quest, which needs all steps.
    func untick(_ quest: Quest, player: Player, now: Date = .now) {
        guard quest.canUntick, let finished = quest.completedAt else { return }
        if let parent = quest.parent, parent.isDone { untick(parent, player: player, now: now) }
        if quest.isRecovery {
            player.recoveries = max(player.recoveries - 1, 0)
        } else {
            // Quests finished before 2026-11-25 did not record their XP: use the rank's.
            let paid = quest.xpEarned > 0 ? quest.xpEarned : quest.rank.xp
            player.totalXP = max(player.totalXP - paid, 0)
            player.add(-min(quest.rank.statPoints, player.value(for: quest.stat)), to: quest.stat)
            player.bankedMinutes = max(player.bankedMinutes - quest.rank.earnedMinutes, 0)
            tally(quest, player: player, at: finished, by: -1)
            // The arc was cleared that day; now it is not.
            if let arc = quest.arc {
                let key = "\(Self.dayKey(finished))|\(arc.title)"
                // Its HP is in hpHealed below, so only the record goes.
                player.clearedArcs.removeAll { $0 == key }
            }
        }
        player.hurt(quest.hpHealed)
        quest.completedAt = nil
        quest.autoCompleted = false
        quest.xpEarned = 0
        quest.hpHealed = 0
        // That day no longer counts toward the streak if nothing else was done.
        let calendar = Calendar.current
        if let context = quest.modelContext {
            let start = calendar.startOfDay(for: finished)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let others = (try? context.fetchCount(FetchDescriptor<Quest>(predicate: #Predicate {
                $0.completedAt != nil && $0.scheduledAt >= start && $0.scheduledAt < end
            }))) ?? 1
            if others == 0 { player.completionDays.removeAll { calendar.isDate($0, inSameDayAs: start) } }
        }
        // A make-up quest open again seals the apps again.
        if quest.isRecovery { ScreenTimeLock.shared.endUnlock() }
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
        for skill in skills {
            let level = skill.level(facts)
            let key = "\(skill.id):\(level)"
            // Only a rise is celebrated: a skill whose thresholds were raised in the
            // database just quietly shows the lower level.
            let known = player.skillLevelsRaw.first { $0.hasPrefix("\(skill.id):") }
                .flatMap { Int($0.split(separator: ":").last ?? "") } ?? 0
            guard level > known, !player.skillLevelsRaw.contains(key) else { continue }
            player.skillLevelsRaw.removeAll { $0.hasPrefix("\(skill.id):") }
            player.skillLevelsRaw.append(key)
            celebrations.append(Celebration(kind: .skill(skill, level: level)))
        }
    }

    /// When the last quest of the day is done: pay the clear bonus and queue the recap.
    private func checkDayClear(_ player: Player, context: ModelContext?, now: Date) {
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
        // Tomorrow's first quest, across every arc still running.
        let arcs = (try? context.fetch(FetchDescriptor<Arc>())) ?? []
        let tomorrow = arcs.dailyPlan(on: now).min { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
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
        ScreenTimeLock.shared.unlock(minutes: 5, now: now)
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
        // Workout counts are all-time totals: stored as they are, never added up.
        if let counts = try? await signals.workoutCounts(), !counts.isEmpty {
            player.workouts = counts[.workouts] ?? player.workouts
            player.cyclingWorkouts = counts[.cyclingWorkouts] ?? player.cyclingWorkouts
            player.swimWorkouts = counts[.swimWorkouts] ?? player.swimWorkouts
            player.danceWorkouts = counts[.danceWorkouts] ?? player.danceWorkouts
            player.martialArtsWorkouts = counts[.martialArtsWorkouts] ?? player.martialArtsWorkouts
            let sports = counts.filter { $0.key.isSport }
            if !sports.isEmpty { player.sportFacts = Dictionary(uniqueKeysWithValues: sports.map { ($0.key.rawValue, $0.value) }) }
            checkSkills(player, now: .now)
        }
        for quest in quests where quest.isOpen && !quest.isBlocked {
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

    // MARK: Hit points and penalties

    /// Every quest of the arc done for the day heals once (`HitPoints.healForClearedArc`).
    private func healIfArcCleared(_ quest: Quest, player: Player, now: Date) {
        guard let arc = quest.arc else { return }
        let calendar = Calendar.current
        let todays = arc.quests.filter { !$0.isRecovery && calendar.isDate($0.scheduledAt, inSameDayAs: now) }
        // This quest is being completed right now, so it counts as done.
        guard todays.allSatisfy({ $0.isDone || $0 === quest }) else { return }
        let key = "\(Self.dayKey(now))|\(arc.title)"
        guard !player.clearedArcs.contains(key) else { return }
        // Only this week's keys are kept; older ones can never match again.
        player.clearedArcs = player.clearedArcs.filter { $0 >= Self.dayKey(now.addingTimeInterval(-7 * 86_400)) } + [key]
        player.heal(HitPoints.healForClearedArc)
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// A must-do that ran past its end time fails at once and costs HP. Its
    /// recovery quest comes with the morning reckoning, or now if HP hit 0.
    func enforcePenalties(quests: [Quest], context: ModelContext, player: Player? = nil, now: Date = .now) {
        for quest in quests where quest.isCritical && quest.isOpen && quest.dueAt < now {
            quest.failedAt = now
            player?.hurt(HitPoints.damageForMustDo)
        }
        if let player, player.condition == .down {
            addRecoveryQuest(for: quests.filter { $0.isFailed }, context: context, now: now)
        }
    }

    /// Once each morning: what yesterday cost, what last night healed, and
    /// whether today starts with a recovery quest. Missing anything yesterday
    /// locks the apps until that quest is done, so the morning gets used.
    func reckon(context: ModelContext, player: Player, now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard player.reckonedDay.map({ !calendar.isDate($0, inSameDayAs: now) }) ?? true,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        // The first morning after an update only starts the count; it does not
        // charge for days before HP existed.
        let firstTime = player.reckonedDay == nil
        player.reckonedDay = today
        guard !firstTime else { return }

        let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= yesterday && $0.scheduledAt < today })
        let yesterdays = (try? context.fetch(descriptor)) ?? []
        // Must-dos already cost HP when they failed, so they are not charged twice.
        let missed = yesterdays.filter { $0.isOpen && !$0.isRecovery && !$0.isCritical }
        let sleep = readings[.sleepHours]
        let score = readings[.sleepScore]
        player.hurt(HitPoints.reckoning(misses: missed.map(\.rank), mustDosMissed: 0,
                                        sleepHours: sleep, sleepScore: score, screenMinutesOver: 0))
        player.heal(HitPoints.healForSleep(hours: sleep, score: score))

        // Yesterday's recovery quest is replaced, never stacked.
        for old in yesterdays where old.isRecovery && old.isOpen { context.delete(old) }
        let failed = yesterdays.filter { $0.isFailed && !$0.isRecovery }
        if !missed.isEmpty || !failed.isEmpty || player.condition == .down {
            addRecoveryQuest(for: missed + failed, context: context, now: now)
        }
    }

    /// One recovery quest a day at most, made from the quest you most need to
    /// make up for: same arc, same stat, a shorter version. Rank D and 15 to 20
    /// minutes, so it is an L you take, not a wall you stop at.
    private func addRecoveryQuest(for missed: [Quest], context: ModelContext, now: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let todays = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate {
            $0.isRecovery && $0.scheduledAt >= start && $0.scheduledAt < end
        }))) ?? []
        guard todays.isEmpty else { return }
        // The hardest miss, and its parent when it was a step.
        let worst = missed.map { $0.parent ?? $0 }.max { ($0.rank, $0.durationMinutes) < ($1.rank, $1.durationMinutes) }
        let title = worst.map { "Make up: \($0.title), short version" } ?? "Make up: 20 push-ups and a 10 min walk"
        let minutes = min(max((worst?.durationMinutes ?? 30) / 2, 15), 20)
        let recovery = Quest(title: title, stat: worst?.stat ?? .willpower, rank: .d, isRecovery: true,
                             scheduledAt: now, durationMinutes: minutes, arc: worst?.arc)
        context.insert(recovery)
        // Close whatever is open right now: the apps stay shut until it is done.
        ScreenTimeLock.shared.endUnlock()
    }

    /// True while a recovery quest is waiting. Everything stays sealed until it is done.
    func isLocked(_ quests: [Quest]) -> Bool {
        quests.contains { $0.isRecovery && $0.isOpen }
    }

    // MARK: Screen time

    func spend(minutes: Int, player: Player) {
        // Lock-in hours: the minutes stay banked for later.
        guard player.bankedMinutes >= minutes, !ScreenTimeLock.shared.isLockIn() else { return }
        player.bankedMinutes -= minutes
        // Opens the locked apps for that long, when the Screen Time lock is on.
        ScreenTimeLock.shared.unlock(minutes: minutes)
    }
}
