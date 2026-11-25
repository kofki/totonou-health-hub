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
    /// True when it answers in a moment, so the Coach tab can ask it on every
    /// visit. The Mac relay answers only questions you type.
    var answersOnOpen: Bool { get }
}

extension CoachAdvisor {
    var answersOnOpen: Bool { true }
}

enum Coach {
    /// The advisor this device has: Apple's on-device model where it exists,
    /// otherwise Claude Code through the Mac relay, or nil with neither.
    static func advisor() -> (any CoachAdvisor)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceAI.isAvailable { return OnDeviceCoachAdvisor() }
        #endif
        // Claude Code on your Mac, on your Claude account (scripts/coach-relay).
        // `CloudCoachAdvisor` (the paid API) stays available but is not used.
        if let client = SupabaseConfig.client { return ClaudeRelayAdvisor(client: client) }
        return nil
    }

    /// `arcs` are the arcs running now; the review covers the bosses of all of them.
    static func review(quests: [Quest], player: Player, arcs: [Arc],
                       readings: [SignalKey: Double] = [:], now: Date = .now) -> CoachReview {
        let bosses = arcs.flatMap(\.bosses)
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
        review.facts.append(arcs.isEmpty ? "Active arcs: none."
            : "Active arcs: " + arcs.map { "\($0.title) (\($0.dayLabel(on: now)))" }.joined(separator: "; ") + ".")
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
        if let v = readings[.activeCalories], v > 0 { parts.append("\(Int(v)) active kcal") }
        if let v = readings[.restingHeartRate] { parts.append("resting heart rate \(Int(v)) bpm") }
        if let v = readings[.hrv] { parts.append("HRV \(Int(v)) ms") }
        if let v = readings[.vo2Max] { parts.append(String(format: "VO2 max %.1f", v)) }
        if let v = readings[.bodyBattery] { parts.append("Body Battery \(Int(v))") }
        if let v = readings[.stress] { parts.append("average stress \(Int(v))") }
        if let v = readings[.sleepScore] { parts.append("sleep score \(Int(v))") }
        if let v = readings[.screenMinutes] { parts.append("at least \(Int(v)) min on the apps chosen for the Screen Time lock") }
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
