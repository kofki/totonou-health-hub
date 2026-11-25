import Foundation
import SwiftData
import TotonouCore

extension Quest {
    /// Returns the quest linked to an objective, so it can be chained after `Quest(…)`.
    func linked(to objective: Objective?) -> Quest {
        self.objective = objective
        return self
    }
}

/// Turns an arc's plan into real quests on a real day.
enum QuestPlanner {
    static func quests(from ideas: [QuestIdea], on day: Date, arc: Arc?) -> [Quest] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        return ideas.filter { $0.runs(on: day) }.map { idea in
            // Quests Health can prove get a target and complete themselves.
            let signal = SignalTarget.guess(from: idea.title)
            return Quest(title: idea.title, stat: idea.stat, rank: idea.rank, source: signal == nil ? .manual : .health,
                         scheduledAt: calendar.date(bySettingHour: idea.hour, minute: idea.minute, second: 0, of: start) ?? start,
                         durationMinutes: idea.minutes, signal: signal?.key, target: signal?.target, arc: arc)
            .linked(to: arc?.objective(named: idea.objective))
        }
    }

    /// Gives a quest the planned steps it does not have yet. Call it after the
    /// quest is inserted and has its final time: steps start with it.
    static func addSteps(_ steps: [QuestIdea.StepIdea], to quest: Quest, context: ModelContext) {
        guard quest.isOpen, quest.parent == nil else { return }
        for planned in steps where !quest.subquests.contains(where: { $0.title == planned.title }) {
            let step = Quest(title: planned.title, stat: quest.stat, rank: planned.rank,
                             // A second apart, so they keep their order (as QuestEngine.addStep does).
                             scheduledAt: quest.scheduledAt.addingTimeInterval(Double(quest.subquests.count)),
                             durationMinutes: planned.minutes, arc: quest.arc)
            step.objective = quest.objective
            context.insert(step)
            quest.subquests.append(step)
        }
    }

    /// Inserts a quest made from a plan, with the steps its idea lists.
    static func insert(_ quest: Quest, from ideas: [QuestIdea], context: ModelContext) {
        context.insert(quest)
        if let idea = ideas.first(where: { $0.title == quest.title }) { addSteps(idea.steps, to: quest, context: context) }
    }

    /// Start a new arc: save it and put its quests on today, next to the quests
    /// of any arc already running.
    /// A season runs 90 days. An objective has no end date: it runs until you close it.
    static func begin(title: String, manifesto: String, draft: ArcDraft, kind: ArcKind = .seasonal,
                      context: ModelContext, now: Date = .now) {
        let start = Calendar.current.startOfDay(for: now)
        let arc = Arc(title: title, kanji: draft.kanji, manifesto: manifesto, goals: draft.goals,
                      // A second later than midnight, so it sorts ahead of an arc started earlier today.
                      startDate: now,
                      endDate: kind == .seasonal ? Calendar.current.date(byAdding: .day, value: 90, to: start)! : .distantFuture,
                      kind: kind)
        arc.questPlan = draft.quests.map(\.line)
        context.insert(arc)
        for (order, idea) in draft.objectives.enumerated() {
            // Appended rather than passing `arc:`, so the arc's list holds it
            // before the quests below look it up by name.
            let objective = Objective(title: idea.title, period: idea.period, target: idea.target,
                                      detail: idea.detail, order: order)
            context.insert(objective)
            arc.objectives.append(objective)
        }
        for quest in quests(from: draft.quests, on: now, arc: arc) { insert(quest, from: draft.quests, context: context) }
    }
}

/// What the app does when it starts: no sample data, just the minimum to run.
enum Bootstrap {
    @MainActor
    static func start(_ context: ModelContext, now: Date = .now) {
        clearSeedDataOnce(context)
        closeSupersededArcsOnce(context)
        if ((try? context.fetchCount(FetchDescriptor<Player>())) ?? 0) == 0 {
            context.insert(Player(name: "Human"))
        }
        // Older installs were created with the default name "Hunter".
        if let player = try? context.fetch(FetchDescriptor<Player>()).first, player.name == "Hunter" {
            player.name = "Human"
        }
        rollDailyQuests(context, now: now)
    }

    /// Creates today's quests from the plan of every active arc that has none
    /// today yet. Quests that land on a busy calendar block move to the next free slot.
    @MainActor
    static func rollDailyQuests(_ context: ModelContext, day: any DaySource = EventKitDaySource.shared, now: Date = .now) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let arcs = ((try? context.fetch(FetchDescriptor<Arc>(sortBy: [SortDescriptor(\.startDate)]))) ?? [])
            .active(on: now).filter { !$0.plan.isEmpty }
        guard !arcs.isEmpty else { return }

        // Checked arc by arc, so an arc started this morning does not stop an
        // older arc from getting its quests, and nothing is created twice.
        let todays = FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= start && $0.scheduledAt < end })
        let served = Set(((try? context.fetch(todays)) ?? []).compactMap { $0.arc?.persistentModelID })
        let waiting = arcs.filter { !served.contains($0.persistentModelID) }
        guard !waiting.isEmpty else { return }

        let busy = day.busyBlocks(on: now)
        for arc in waiting {
            for quest in QuestPlanner.quests(from: arc.plan, on: now, arc: arc) {
                if let free = DayPlanner.firstFreeStart(at: quest.scheduledAt, minutes: quest.durationMinutes, busy: busy, dayEnd: end) {
                    quest.scheduledAt = free
                }
                QuestPlanner.insert(quest, from: arc.plan, context: context)
            }
        }
    }

    /// Before arcs could run side by side, starting a new arc replaced the one
    /// before it. This marks those replaced arcs as ended, once, so they do not
    /// come back to life and fill Today with their old quests.
    @MainActor
    private static func closeSupersededArcsOnce(_ context: ModelContext) {
        let key = "didCloseSupersededArcs.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let arcs = (try? context.fetch(FetchDescriptor<Arc>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? []
        // zip pairs each arc with the next older one: (newest, second), (second, third)…
        for (newer, older) in zip(arcs, arcs.dropFirst()) where older.endedAt == nil {
            older.endedAt = newer.startDate
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
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
