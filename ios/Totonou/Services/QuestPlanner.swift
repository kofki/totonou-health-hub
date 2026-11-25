import Foundation
import SwiftData
import TotonouCore

/// Turns an arc's plan into real quests on a real day.
enum QuestPlanner {
    static func quests(from ideas: [QuestIdea], on day: Date, arc: Arc?) -> [Quest] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        return ideas.map { idea in
            // Quests Health can prove get a target and complete themselves.
            let signal = SignalTarget.guess(from: idea.title)
            return Quest(title: idea.title, stat: idea.stat, rank: idea.rank, source: signal == nil ? .manual : .health,
                         scheduledAt: calendar.date(bySettingHour: idea.hour, minute: idea.minute, second: 0, of: start) ?? start,
                         durationMinutes: idea.minutes, signal: signal?.key, target: signal?.target, arc: arc)
        }
    }

    /// Start a new arc: save it, and swap today's unfinished quests for the arc's own.
    /// Quests you already finished today stay, with their rewards.
    static func begin(title: String, manifesto: String, draft: ArcDraft, todays: [Quest],
                      context: ModelContext, now: Date = .now) {
        let start = Calendar.current.startOfDay(for: now)
        let arc = Arc(title: title, kanji: draft.kanji, manifesto: manifesto, goals: draft.goals,
                      // A second later than midnight, so it sorts ahead of an arc started earlier today.
                      startDate: now, endDate: Calendar.current.date(byAdding: .day, value: 90, to: start)!)
        arc.questPlan = draft.quests.map(\.line)
        context.insert(arc)
        for quest in todays where quest.isOpen { context.delete(quest) }
        for quest in quests(from: draft.quests, on: now, arc: arc) { context.insert(quest) }
    }
}

/// What the app does when it starts: no sample data, just the minimum to run.
enum Bootstrap {
    @MainActor
    static func start(_ context: ModelContext, now: Date = .now) {
        clearSeedDataOnce(context)
        if ((try? context.fetchCount(FetchDescriptor<Player>())) ?? 0) == 0 {
            context.insert(Player(name: "Human"))
        }
        // Older installs were created with the default name "Hunter".
        if let player = try? context.fetch(FetchDescriptor<Player>()).first, player.name == "Hunter" {
            player.name = "Human"
        }
        rollDailyQuests(context, now: now)
    }

    /// Creates today's quests from the current arc's plan, if today has none yet.
    /// Quests that land on a busy calendar block move to the next free slot.
    @MainActor
    static func rollDailyQuests(_ context: ModelContext, day: any DaySource = EventKitDaySource.shared, now: Date = .now) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let todays = FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= start && $0.scheduledAt < end })
        guard ((try? context.fetchCount(todays)) ?? 0) == 0 else { return }

        var newest = FetchDescriptor<Arc>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        newest.fetchLimit = 1
        guard let arc = try? context.fetch(newest).first, !arc.plan.isEmpty else { return }
        let busy = day.busyBlocks(on: now)
        for quest in QuestPlanner.quests(from: arc.plan, on: now, arc: arc) {
            if let free = DayPlanner.firstFreeStart(at: quest.scheduledAt, minutes: quest.durationMinutes, busy: busy, dayEnd: end) {
                quest.scheduledAt = free
            }
            context.insert(quest)
        }
    }

    /// Earlier builds filled the app with sample quests, an arc and bosses. This
    /// removes them, once, so the app only ever shows what you created.
    @MainActor
    private static func clearSeedDataOnce(_ context: ModelContext) {
        let key = "didClearSeedData.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        // One by one rather than context.delete(model:): a batch delete refuses
        // to run on models that have relationships to tidy up.
        func removeAll<Model: PersistentModel>(_ type: Model.Type) {
            for object in (try? context.fetch(FetchDescriptor<Model>())) ?? [] { context.delete(object) }
        }
        removeAll(BossTask.self)
        removeAll(Boss.self)
        removeAll(Quest.self)
        removeAll(Arc.self)
        removeAll(Player.self)
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
