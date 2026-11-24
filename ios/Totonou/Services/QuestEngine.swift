import Foundation
import Observation
import SwiftData
import TotonouCore

/// What a finished quest or a boss hit just paid. Shown as a banner by RootView.
struct RewardNotice: Identifiable, Equatable {
    let id = UUID()
    let xp: Int
    var stat: Stat?
    var points = 0
    var minutes = 0
}

/// The game loop: completing quests, paying rewards, auto-completion, penalties.
/// Views never change XP or stats themselves — they ask the engine.
@MainActor
@Observable
final class QuestEngine {
    /// Set to the new level when the player levels up. The root view shows an overlay.
    var levelUp: Int?
    /// Set whenever something pays out. The root view clears it after a moment.
    var notice: RewardNotice?
    var isSyncing = false
    var lastSync: Date?

    /// Where the cloud backup stands. Shown on the Status screen.
    var cloudState: CloudState

    /// Whether quest reminders are switched on. Remembered between launches.
    private(set) var remindersOn = UserDefaults.standard.bool(forKey: "remindersOn")

    private let signals: any SignalSource
    private let cloud: any CloudStore
    private let reminders: any Reminders

    init(signals: any SignalSource = HealthKitSignalSource(), cloud: any CloudStore = MockCloudStore(),
         reminders: any Reminders = LocalReminders()) {
        self.signals = signals
        self.cloud = cloud
        self.reminders = reminders
        self.cloudState = cloud is MockCloudStore ? .local : .syncing
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
        if !quest.isRecovery {
            reward(player, xp: quest.rank.xp)
            player.add(quest.rank.statPoints, to: quest.stat)
            player.bankedMinutes += quest.rank.earnedMinutes
            notice = RewardNotice(xp: quest.rank.xp, stat: quest.stat,
                                  points: quest.rank.statPoints, minutes: quest.rank.earnedMinutes)
        }
        let day = Calendar.current.startOfDay(for: now)
        if !player.completionDays.contains(day) {
            player.completionDays.append(day)
        }
    }

    /// Land a hit on a boss by finishing one of its subtasks.
    func strike(_ task: BossTask, player: Player) {
        guard !task.isDone else { return }
        task.isDone = true
        Sounds.play(.hit)
        player.add(1, to: .discipline)
        let defeated = task.boss?.isDefeated ?? false
        reward(player, xp: defeated ? 300 : 25)
        notice = RewardNotice(xp: defeated ? 300 : 25, stat: .discipline, points: 1)
    }

    private func reward(_ player: Player, xp: Int) {
        let before = player.progress.level
        player.totalXP += xp
        let after = player.progress.level
        if after > before {
            levelUp = after
            Sounds.play(.levelUp)
        }
    }

    // MARK: Auto-completion

    /// Pull the latest readings and complete every quest whose target is met.
    func sync(quests: [Quest], player: Player) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        guard let readings = try? await signals.latest() else { return }
        for quest in quests where quest.isOpen {
            guard let raw = quest.signalKey, let key = SignalKey(rawValue: raw),
                  let target = quest.target, let value = readings[key] else { continue }
            if value >= target {
                complete(quest, player: player, auto: true)
            }
        }
        lastSync = .now
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
