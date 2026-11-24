import Foundation
import TotonouCore

// The coach reads what you actually did and says something about it. Every
// number here is computed from the database or from Apple Health; nothing is
// canned, and the language model only ever sees these measured facts.

struct DayTally: Identifiable, Sendable {
    let date: Date
    var done = 0
    var total = 0
    var id: Date { date }
    /// Mon, Tue…
    var label: String { date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "en_US"))) }
}

struct CoachSuggestion: Identifiable, Sendable {
    let title: String
    let idea: QuestIdea
    var id: String { title }
}

/// One finding, with the icon that says what it is about.
struct CoachInsight: Identifiable, Sendable, Hashable {
    enum Kind: Sendable { case timing, missed, stats, boss, health, streak }
    let kind: Kind
    let text: String
    var id: String { text }
}

struct CoachReview: Sendable {
    var done = 0
    var total = 0
    var missed = 0
    var streak = 0
    var days: [DayTally] = []
    var insights: [CoachInsight] = []
    var suggestions: [CoachSuggestion] = []
    /// Each measured fact as a labelled line. Shown to you as "What the coach
    /// saw", and the only thing the language model is given.
    var facts: [String] = []

    var factSheet: String { facts.map { "- \($0)" }.joined(separator: "\n") }
}

/// Something that can turn the week's facts into a few sentences of advice.
protocol CoachAdvisor: Sendable {
    func advise(facts: String, question: String?) async throws -> String
}

enum Coach {
    /// The advisor this device has, or nil when there is no on-device model.
    static func advisor() -> (any CoachAdvisor)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceAI.isAvailable { return OnDeviceCoachAdvisor() }
        #endif
        return nil
    }

    static func review(quests: [Quest], player: Player, bosses: [Boss],
                       readings: [SignalKey: Double] = [:], now: Date = .now) -> CoachReview {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        // Everything that was due by now, plus anything finished early.
        let week = quests.filter { $0.scheduledAt >= start && ($0.scheduledAt <= now || $0.isDone) && !$0.isRecovery }

        var review = CoachReview()
        review.total = week.count
        review.done = week.filter(\.isDone).count
        review.missed = week.filter { $0.isFailed || ($0.isOpen && $0.dueAt < today) }.count
        review.streak = player.streak(on: now)
        review.days = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let that = week.filter { calendar.isDate($0.scheduledAt, inSameDayAs: day) }
            return DayTally(date: day, done: that.filter(\.isDone).count, total: that.count)
        }

        // Facts first: plain measurements, each labelled with what it is.
        review.facts.append("Last 7 days: \(review.done) of \(review.total) quests done, \(review.missed) missed.")
        review.facts.append("Current streak: \(review.streak) day\(review.streak == 1 ? "" : "s").")
        let openToday = quests.filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) && $0.isOpen }
        review.facts.append(openToday.isEmpty ? "Open quests today: none."
            : "Open quests today: " + openToday.map { "\($0.title) at \($0.scheduledAt.clock)" }.joined(separator: "; ") + ".")
        review.facts.append("Stats: " + Stat.allCases.map { "\($0.title) \(player.value(for: $0))" }.joined(separator: ", ") + ".")
        review.facts.append(healthFact(readings))

        // Which part of the day works, and which does not. Needs 3+ quests per part.
        let parts: [(name: String, hours: Range<Int>)] = [("morning", 0..<12), ("afternoon", 12..<18), ("evening", 18..<24)]
        let rates: [(name: String, rate: Double)] = parts.compactMap { part in
            let finished = week.filter { $0.dueAt < now && part.hours.contains(calendar.component(.hour, from: $0.scheduledAt)) }
            guard finished.count >= 3 else { return nil }
            return (part.name, Double(finished.filter(\.isDone).count) / Double(finished.count))
        }
        if let best = rates.max(by: { $0.rate < $1.rate }), let worst = rates.min(by: { $0.rate < $1.rate }),
           best.rate - worst.rate >= 0.15 {
            review.insights.append(CoachInsight(kind: .timing,
                text: "You finish \(Int(best.rate * 100))% of \(best.name) quests but only \(Int(worst.rate * 100))% in the \(worst.name)."))
        }

        if review.missed > 0 {
            review.insights.append(CoachInsight(kind: .missed,
                text: "\(review.missed) quest\(review.missed == 1 ? "" : "s") missed this week."))
        }

        if review.streak >= 3 {
            review.insights.append(CoachInsight(kind: .streak, text: "\(review.streak)-day streak. Don't break it today."))
        }

        // The stat that is falling behind: only once stats exist and actually differ.
        let soon = min(calendar.component(.hour, from: now) + 1, 22)
        let values = Stat.allCases.map { ($0, player.value(for: $0)) }
        if let low = values.min(by: { $0.1 < $1.1 }), let high = values.max(by: { $0.1 < $1.1 }), high.1 > low.1 {
            review.insights.append(CoachInsight(kind: .stats,
                text: "\(low.0.title) is lowest (\(low.1)); \(high.0.title) is highest (\(high.1))."))
            review.suggestions.append(CoachSuggestion(title: "Train \(low.0.title)", idea: starter(for: low.0, hour: soon)))
        }

        if let steps = readings[.steps], steps > 0 {
            review.insights.append(CoachInsight(kind: .health, text: "\(Int(steps).formatted()) steps so far today."))
        }

        // The boss closest to its deadline.
        if let boss = bosses.filter({ !$0.isDefeated }).min(by: { $0.deadline < $1.deadline }),
           let task = boss.orderedTasks.first(where: { !$0.isDone }) {
            let line = "\(boss.name): \(boss.remaining) task\(boss.remaining == 1 ? "" : "s") left, \(boss.daysLeft) days to the deadline."
            review.facts.append("Boss " + line)
            review.insights.append(CoachInsight(kind: .boss, text: line))
            review.suggestions.append(CoachSuggestion(
                title: "Hit \(boss.name)",
                idea: QuestIdea(title: task.title, stat: .discipline, hour: soon, minutes: 45, rank: .c)
            ))
        }
        return review
    }

    /// Today's Health readings, or a clear statement that there are none.
    private static func healthFact(_ readings: [SignalKey: Double]) -> String {
        var parts: [String] = []
        if let v = readings[.steps] { parts.append("\(Int(v)) steps") }
        if let v = readings[.runKm], v > 0 { parts.append(String(format: "%.1f km run", v)) }
        if let v = readings[.sleepHours], v > 0 { parts.append(String(format: "%.1f h sleep last night", v)) }
        if let v = readings[.focusMinutes], v > 0 { parts.append("\(Int(v)) mindful minutes") }
        return parts.isEmpty ? "Apple Health today: no data." : "Apple Health today: " + parts.joined(separator: ", ") + "."
    }

    private static func starter(for stat: Stat, hour: Int) -> QuestIdea {
        switch stat {
        case .strength: QuestIdea(title: "20 push-ups", stat: stat, hour: hour, minutes: 5, rank: .e)
        case .endurance: QuestIdea(title: "Walk 20 min", stat: stat, hour: hour, minutes: 20, rank: .e)
        case .intellect: QuestIdea(title: "Read 15 min", stat: stat, hour: hour, minutes: 15, rank: .e)
        case .discipline: QuestIdea(title: "Plan tomorrow", stat: stat, hour: hour, minutes: 5, rank: .e)
        case .recovery: QuestIdea(title: "Stretch 10 min", stat: stat, hour: hour, minutes: 10, rank: .e)
        }
    }
}
