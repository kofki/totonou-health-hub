import Foundation
import SwiftData
import TotonouCore

// The engine's side of the Claude link (ClaudeLink.swift): what Claude is
// shown, and how its requests become real quests, arcs and objectives.
// Everything Claude does goes through here, so the game's rules still hold:
// Claude can plan, but only finishing a quest pays XP.

extension QuestEngine {
    /// Upload the document Claude reads. Called at every backup and when you
    /// make a link. Quietly does nothing when Supabase is not configured.
    func shareWithClaude(context: ModelContext, now: Date = .now) async {
        guard let link = ClaudeLinks.make(),
              let data = try? ClaudeSnapshot.make(context: context, readings: readings, now: now) else { return }
        // Nothing changed since the last upload (the timestamp aside): skip it.
        let fingerprint = ClaudeSnapshot.fingerprint(data)
        guard fingerprint != lastClaudeSnapshot else { return }
        do {
            try await link.upload(snapshot: data)
            lastClaudeSnapshot = fingerprint
        } catch {}
    }

    /// Apply every change Claude left, oldest first, then save. Each change is
    /// stamped with what happened, so it is never applied twice.
    func applyClaudeChanges(context: ModelContext, now: Date = .now) async {
        guard !isApplyingClaude, let link = ClaudeLinks.make() else { return }
        isApplyingClaude = true
        defer { isApplyingClaude = false }
        guard let changes = try? await link.pendingChanges(), !changes.isEmpty else { return }
        var applied = 0
        var subjects: [String] = []
        for change in changes {
            let result = ClaudeApplier(context: context, engine: self, now: now).apply(change)
            // Save before stamping: if the app is closed in between, the worst
            // case is a change applied but not stamped, which the duplicate
            // checks below turn into a no-op next time.
            try? context.save()
            try? await link.markApplied(change.id, result: result)
            if result.hasPrefix("applied") {
                applied += 1
                // What the update was about: the arc when there is one, else the item itself.
                if change.kind != .coachMessage, let subject = change.payload.arc ?? change.payload.title,
                   !subjects.contains(subject) {
                    subjects.append(subject)
                }
            }
        }
        if applied > 0 {
            // Added to today's, so a second batch later today does not hide the first.
            let earlier = claudeApplied.flatMap { Calendar.current.isDate($0.at, inSameDayAs: now) ? $0 : nil }
            let all = (earlier?.subjects ?? []) + subjects.filter { !(earlier?.subjects ?? []).contains($0) }
            claudeApplied = ClaudeActivity(count: (earlier?.count ?? 0) + applied, subjects: all, at: now)
        }
        await shareWithClaude(context: context, now: now)
    }
}

/// How many of Claude's changes were applied, what they were about, and when. Shown on Today.
struct ClaudeActivity: Equatable, Sendable {
    let count: Int
    /// Arc titles, or quest and objective titles when there was no arc.
    let subjects: [String]
    let at: Date

    /// "There has been an update for Founder and Healthy body."
    var message: String {
        guard !subjects.isEmpty else { return "There has been an update to your plan." }
        let named = subjects.count <= 2 ? subjects.joined(separator: " and ")
            : subjects.prefix(2).joined(separator: ", ") + " and \(subjects.count - 2) more"
        return "There has been an update for \(named)."
    }
}

/// Where the latest coach message from Claude is kept. Read by CoachView.
enum ClaudeCoachNote {
    static let textKey = "claudeCoachText"
    static let dateKey = "claudeCoachDate"

    static func save(_ text: String, at date: Date) {
        UserDefaults.standard.set(text, forKey: textKey)
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: dateKey)
    }
}

// MARK: Applying

@MainActor
private struct ClaudeApplier {
    let context: ModelContext
    let engine: QuestEngine
    let now: Date

    private var calendar: Calendar { Calendar.current }

    func apply(_ change: ClaudeChange) -> String {
        let p = change.payload
        switch change.kind {
        case .addQuest: return addQuest(p)
        case .removeQuest: return removeQuest(p)
        case .addDailyQuest: return addDailyQuest(p)
        case .addArc: return addArc(p)
        case .endArc: return endArc(p)
        case .addObjective: return addObjective(p)
        case .setSteps: return setSteps(p)
        case .coachMessage:
            guard let text = p.text else { return "skipped: no text" }
            ClaudeCoachNote.save(text, at: now)
            return "applied"
        }
    }

    // Lookups

    private func arcs() -> [Arc] {
        (try? context.fetch(FetchDescriptor<Arc>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? []
    }

    /// An arc by title, ignoring case. Running arcs come first.
    private func arc(named title: String?) -> Arc? {
        guard let title else { return nil }
        let matches = arcs().filter { $0.title.compare(title, options: .caseInsensitive) == .orderedSame }
        return matches.first { $0.isActive(on: now) } ?? matches.first
    }

    /// "2026-12-01" + "07:30" in this phone's time zone.
    private func moment(date: String?, time: String?) -> Date? {
        guard let date, let time else { return nil }
        let day = date.split(separator: "-").compactMap { Int($0) }
        let clock = time.split(separator: ":").compactMap { Int($0) }
        guard day.count == 3, clock.count == 2 else { return nil }
        return calendar.date(from: DateComponents(year: day[0], month: day[1], day: day[2], hour: clock[0], minute: clock[1]))
    }

    private func day(_ text: String?) -> Date? {
        moment(date: text, time: "00:00")
    }

    private func idea(_ p: ClaudeChange.Payload) -> QuestIdea? {
        guard let title = p.title, let stat = p.stat.flatMap(Stat.init(rawValue:)),
              let clock = p.time?.split(separator: ":").compactMap({ Int($0) }), clock.count == 2 else { return nil }
        return QuestIdea(title: title, stat: stat, hour: clock[0], minute: clock[1], minutes: p.minutes ?? 15,
                         rank: p.rank.flatMap(Rank.init(rawValue:)) ?? .d, objective: p.objective,
                         weekdays: Set(p.weekdays ?? []), steps: steps(p.steps))
    }

    private func steps(_ items: [ClaudeChange.Payload]?) -> [QuestIdea.StepIdea] {
        (items ?? []).compactMap { item in
            guard let title = item.title else { return nil }
            return QuestIdea.StepIdea(title: title, minutes: item.minutes ?? 10,
                                      rank: item.rank.flatMap(Rank.init(rawValue:)) ?? .e)
        }
    }

    /// A quest from Claude's fields. Health-provable quests get a signal: the
    /// one Claude chose, or a guess from the title like any other quest.
    private func quest(_ p: ClaudeChange.Payload, at time: Date, arc: Arc?) -> Quest? {
        guard let idea = idea(p) else { return nil }
        let chosen = p.signal.flatMap(SignalKey.init(rawValue:)).map { (key: $0, target: p.target ?? 0) }
        let signal = chosen ?? SignalTarget.guess(from: idea.title)
        return Quest(title: idea.title, stat: idea.stat, rank: idea.rank, source: signal == nil ? .manual : .health,
                     isCritical: p.mustDo ?? false, scheduledAt: time, durationMinutes: idea.minutes,
                     signal: signal?.key, target: signal?.target, arc: arc)
            .linked(to: arc?.objective(named: p.objective))
    }

    private func exists(title: String, at time: Date) -> Bool {
        let quests = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt == time }))) ?? []
        return quests.contains { $0.title == title }
    }

    // Changes

    private func addQuest(_ p: ClaudeChange.Payload) -> String {
        if let parentTitle = p.partOf { return addStep(p, to: parentTitle) }
        guard let time = moment(date: p.date, time: p.time), let title = p.title else { return "skipped: bad date or time" }
        guard time >= calendar.startOfDay(for: now) else { return "skipped: that day is over" }
        guard !exists(title: title, at: time) else { return "skipped: already there" }
        let arc = arc(named: p.arc)
        if p.arc != nil && arc == nil { return "skipped: no arc called \(p.arc!)" }
        guard let quest = quest(p, at: time, arc: arc) else { return "skipped: bad quest" }
        context.insert(quest)
        QuestPlanner.addSteps(steps(p.steps), to: quest, context: context)
        return "applied"
    }

    /// A checklist for a quest: in its arc's daily plan, so every day's copy
    /// gets it, and on the open quests with that title from today on.
    private func setSteps(_ p: ClaudeChange.Payload) -> String {
        guard let title = p.title else { return "skipped: no title" }
        let list = steps(p.steps)
        guard !list.isEmpty else { return "skipped: no steps" }
        func same(_ other: String) -> Bool { other.compare(title, options: .caseInsensitive) == .orderedSame }
        var found = false

        let planArcs = p.arc.map { name in arc(named: name).map { [$0] } ?? [] } ?? arcs().filter { $0.isActive(on: now) }
        for arc in planArcs where arc.isActive(on: now) {
            var plan = arc.plan
            guard let index = plan.firstIndex(where: { same($0.title) }) else { continue }
            plan[index].steps = list
            arc.questPlan = plan.map(\.line)
            found = true
        }

        var start = calendar.startOfDay(for: now)
        if let date = day(p.date) { start = date }
        let end = p.date == nil ? Date.distantFuture : calendar.date(byAdding: .day, value: 1, to: start)!
        let quests = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= start && $0.scheduledAt < end }))) ?? []
        for quest in quests where quest.parent == nil && quest.isOpen && same(quest.title) {
            if let name = p.arc, quest.arc?.title.compare(name, options: .caseInsensitive) != .orderedSame { continue }
            QuestPlanner.addSteps(list, to: quest, context: context)
            found = true
        }
        return found ? "applied" : "skipped: no open or planned quest called \(title)"
    }

    /// A step of a quest already on that day, found by title.
    private func addStep(_ p: ClaudeChange.Payload, to parentTitle: String) -> String {
        guard let day = self.day(p.date), let title = p.title,
              let end = calendar.date(byAdding: .day, value: 1, to: day) else { return "skipped: bad date" }
        let quests = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= day && $0.scheduledAt < end }))) ?? []
        guard let parent = quests.first(where: { $0.parent == nil && $0.title.compare(parentTitle, options: .caseInsensitive) == .orderedSame }) else {
            return "skipped: no quest called \(parentTitle) that day"
        }
        guard !parent.subquests.contains(where: { $0.title == title }) else { return "skipped: already a step" }
        guard let step = engine.addStep(title, to: parent, minutes: p.minutes ?? 15, context: context) else {
            return "skipped: that quest is finished"
        }
        if let rank = p.rank.flatMap(Rank.init(rawValue:)) { step.rankRaw = rank.rawValue }
        if let stat = p.stat.flatMap(Stat.init(rawValue:)) { step.statRaw = stat.rawValue }
        // A step counts toward its quest's objective unless Claude names another one.
        if let named = parent.arc?.objective(named: p.objective) { step.objective = named }
        if p.mustDo == true { step.isCritical = true }
        return "applied"
    }

    private func removeQuest(_ p: ClaudeChange.Payload) -> String {
        guard let time = moment(date: p.date, time: p.time), let title = p.title else { return "skipped: bad date or time" }
        // The whole minute: steps start a few seconds after their quest, to keep their order.
        let end = time.addingTimeInterval(60)
        let quests = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.scheduledAt >= time && $0.scheduledAt < end }))) ?? []
        guard let quest = quests.first(where: { $0.title.compare(title, options: .caseInsensitive) == .orderedSame }) else {
            return "skipped: no such quest"
        }
        guard quest.isOpen, !quest.isRecovery else { return "skipped: finished, failed or recovery quests stay" }
        if let id = quest.alarmID { engine.alarms.cancel(id: id) }
        context.delete(quest)
        return "applied"
    }

    private func addDailyQuest(_ p: ClaudeChange.Payload) -> String {
        guard let arc = arc(named: p.arc), arc.isActive(on: now) else { return "skipped: no running arc called \(p.arc ?? "")" }
        guard let idea = idea(p) else { return "skipped: bad quest" }
        guard !arc.plan.contains(where: { $0.title == idea.title }) else { return "skipped: already in the plan" }
        arc.questPlan.append(idea.line)
        // Today's quests were already made this morning: add this one now if
        // it is for today and still ahead.
        if idea.runs(on: now), let start = calendar.date(bySettingHour: idea.hour, minute: idea.minute, second: 0, of: now),
           start > now, !exists(title: idea.title, at: start), let quest = quest(p, at: start, arc: arc) {
            context.insert(quest)
            QuestPlanner.addSteps(idea.steps, to: quest, context: context)
        }
        return "applied"
    }

    private func addObjective(_ p: ClaudeChange.Payload) -> String {
        guard let arc = arc(named: p.arc), arc.isActive(on: now) else { return "skipped: no running arc called \(p.arc ?? "")" }
        guard let title = p.title else { return "skipped: no title" }
        guard arc.objective(named: title) == nil else { return "skipped: the arc already has it" }
        let objective = Objective(title: title, period: p.period.flatMap(ObjectivePeriod.init(rawValue:)) ?? .week,
                                  target: p.count ?? 1, detail: p.detail ?? "",
                                  order: (arc.objectives.map(\.order).max() ?? -1) + 1)
        context.insert(objective)
        arc.objectives.append(objective)
        return "applied"
    }

    private func addArc(_ p: ClaudeChange.Payload) -> String {
        guard let title = p.title else { return "skipped: no title" }
        guard !arcs().contains(where: { $0.isActive(on: now) && $0.title.compare(title, options: .caseInsensitive) == .orderedSame }) else {
            return "skipped: an arc with this name is already running"
        }
        let kind: ArcKind = p.kind == "seasonal" ? .seasonal : .objective
        let start = day(p.startDate).map { max($0, calendar.startOfDay(for: now)) } ?? now
        let end: Date
        if kind == .seasonal {
            // The end date is the last day of the arc, so it runs to that midnight.
            guard let last = day(p.endDate), last >= start,
                  let after = calendar.date(byAdding: .day, value: 1, to: last) else { return "skipped: bad end date" }
            end = after
        } else {
            end = .distantFuture
        }

        let objectives = (p.objectives ?? []).compactMap { item -> ObjectiveIdea? in
            guard let title = item.title else { return nil }
            return ObjectiveIdea(title: title, period: item.period.flatMap(ObjectivePeriod.init(rawValue:)) ?? .week,
                                 target: item.count ?? 1, detail: item.detail ?? "")
        }
        let draft = ArcDraft(kanji: "道", goals: p.goals ?? [], objectives: objectives,
                             quests: (p.dailyQuests ?? []).compactMap(idea), byAI: true)
        // The same path as an arc you start yourself, then moved to its dates.
        QuestPlanner.begin(title: title, manifesto: p.manifesto ?? "", draft: draft, kind: kind, context: context, now: now)
        if let arc = arcs().first(where: { $0.title == title && $0.endedAt == nil }) {
            arc.endDate = end
            if start > now {
                // Starts later: no quests today. The daily roll makes them on the day.
                arc.startDate = start
                for quest in arc.quests where quest.isOpen { context.delete(quest) }
            }
        }
        return "applied"
    }

    private func endArc(_ p: ClaudeChange.Payload) -> String {
        guard let arc = arc(named: p.arc), arc.isActive(on: now) else { return "skipped: no running arc called \(p.arc ?? "")" }
        engine.end(arc, context: context, now: now)
        return "applied"
    }
}

// MARK: What Claude reads

/// One JSON document with everything measured about the game. Built fresh from
/// the database each time; nothing in it is made up or cached.
enum ClaudeSnapshot {
    /// The snapshot without its "generatedAt" line, so two snapshots of the
    /// same game compare equal however far apart they were made.
    static func fingerprint(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self).replacingOccurrences(of: #""generatedAt":"[^"]*","#, with: "",
                                                                    options: .regularExpression)
    }

    @MainActor
    static func make(context: ModelContext, readings: [SignalKey: Double], now: Date) throws -> Data {
        let calendar = Calendar.current
        let player = try context.fetch(FetchDescriptor<Player>()).first
        let arcs = try context.fetch(FetchDescriptor<Arc>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))
        let from = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now))!
        let to = calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: now))!
        let quests = try context.fetch(FetchDescriptor<Quest>(
            predicate: #Predicate { $0.scheduledAt >= from && $0.scheduledAt < to },
            sortBy: [SortDescriptor(\.scheduledAt)]))
        let review = player.map { Coach.review(quests: quests, player: $0, arcs: arcs.active(on: now), readings: readings, now: now) }

        func day(_ date: Date) -> String {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }
        func clock(_ date: Date) -> String { String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date)) }

        func objectiveJSON(_ objective: Objective) -> [String: Any] {
            [
                "title": objective.title,
                "period": objective.period.rawValue,
                "target": objective.target,
                "detail": objective.detail,
                "done": objective.done(on: now),
                "plannedStillOpen": objective.planned(on: now),
                "met": objective.isMet(on: now),
            ]
        }

        func arcJSON(_ arc: Arc) -> [String: Any] {
            let progress = arc.progress(on: now)
            var json: [String: Any] = [
                "title": arc.title,
                "kind": arc.kind.rawValue,
                "manifesto": arc.manifesto,
                "active": arc.isActive(on: now),
                "startDate": day(arc.startDate),
                "dayLabel": arc.dayLabel(on: now),
                "outcomes": arc.goals.map { ["text": $0, "reached": arc.isDone($0)] },
                "objectives": arc.orderedObjectives.map(objectiveJSON),
                "dailyPlan": arc.plan.map { idea -> [String: Any] in
                    var line: [String: Any] = ["title": idea.title, "stat": idea.stat.rawValue, "rank": idea.rank.rawValue,
                                               "time": idea.clock, "minutes": idea.minutes, "days": idea.daysLabel]
                    if let objective = idea.objective { line["objective"] = objective }
                    if !idea.steps.isEmpty {
                        line["steps"] = idea.steps.map { ["title": $0.title, "minutes": $0.minutes, "rank": $0.rank.rawValue] }
                    }
                    return line
                },
                "progress": [
                    "questsDone": progress.questsDone, "questsDue": progress.questsDue,
                    "bossTasksDone": progress.tasksDone, "bossTasks": progress.tasks,
                ],
                "bosses": arc.bosses.map { boss -> [String: Any] in
                    ["name": boss.name, "deadline": day(boss.deadline),
                     "tasks": boss.orderedTasks.map { ["title": $0.title, "done": $0.isDone] }]
                },
            ]
            if arc.kind == .seasonal { json["endDate"] = day(calendar.date(byAdding: .day, value: -1, to: arc.endDate) ?? arc.endDate) }
            if let ended = arc.endedAt { json["endedAt"] = day(ended) }
            return json
        }

        func questJSON(_ quest: Quest) -> [String: Any] {
            let status: String
            if quest.isDone { status = quest.autoCompleted ? "done (proved by data)" : "done" }
            else if quest.isFailed { status = "failed" }
            else if quest.dueAt < now { status = "missed" }
            else { status = "open" }
            var json: [String: Any] = [
                "title": quest.title, "date": day(quest.scheduledAt), "time": clock(quest.scheduledAt),
                "minutes": quest.durationMinutes, "stat": quest.statRaw, "rank": quest.rankRaw,
                "status": status, "source": quest.sourceRaw,
            ]
            if let arc = quest.arc { json["arc"] = arc.title }
            if let objective = quest.objective { json["objective"] = objective.title }
            if let parent = quest.parent { json["partOf"] = parent.title }
            if !quest.subquests.isEmpty {
                // The quest waits for these; each one pays its own reward.
                json["steps"] = quest.orderedSubquests.map { step -> [String: Any] in
                    ["title": step.title, "done": step.isDone, "rank": step.rankRaw, "minutes": step.durationMinutes]
                }
                json["stepsDone"] = "\(quest.subquestsDone)/\(quest.subquests.count)"
                json["lockedUntilStepsDone"] = quest.isBlocked
            }
            if quest.isCritical { json["mustDo"] = true }
            if let finished = quest.completedAt { json["finishedAt"] = clock(finished) }
            return json
        }

        var json: [String: Any] = [
            "generatedAt": ISO8601DateFormatter().string(from: now),
            "timeZone": TimeZone.current.identifier,
            "today": day(now),
            "weekday": Weekday.names[Weekday.isoNumber(of: now) - 1],
            "activeArcs": arcs.active(on: now).map(arcJSON),
            "finishedArcs": arcs.filter { !$0.isActive(on: now) }.prefix(10).map { ["title": $0.title, "kind": $0.kind.rawValue,
                                                                                    "completed": $0.isCompleted] },
            "quests": quests.map(questJSON),
            "coachFacts": review?.facts ?? [],
            "healthToday": Dictionary(uniqueKeysWithValues: readings.map { ($0.key.rawValue, $0.value) }),
            // Daily minutes on the apps chosen for the Screen Time lock, last 30 finished days.
            "screenTimeHistory": ScreenTimeLock.usageHistory().suffix(30).map { ["day": $0.day, "minutes": $0.minutes] as [String: Any] },
        ]
        if let player {
            let level = player.progress.level
            json["player"] = [
                "name": player.name, "level": level, "rank": Rank.forLevel(level).rawValue, "totalXP": player.totalXP,
                "streakDays": player.streak(on: now), "bankedScreenMinutes": player.bankedMinutes,
                "stats": Dictionary(uniqueKeysWithValues: Stat.allCases.map { ($0.rawValue, player.value(for: $0)) }),
            ]
        }
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }
}
