import Foundation
import TotonouCore

// The coach reads what you actually did and says something about it. Everything
// here is computed from the quests in the database; nothing is canned.

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

struct CoachReview: Sendable {
    var done = 0
    var total = 0
    var missed = 0
    var xp = 0
    var days: [DayTally] = []
    var insights: [String] = []
    var suggestions: [CoachSuggestion] = []

    /// The same facts as plain text, for the language model.
    var facts: String {
        (["Quests finished in the last 7 days: \(done) of \(total). Missed: \(missed). XP earned: \(xp)."] + insights)
            .joined(separator: "\n")
    }
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

    static func review(quests: [Quest], player: Player, bosses: [Boss], now: Date = .now) -> CoachReview {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        // Everything that was due by now, plus anything finished early.
        let week = quests.filter { $0.scheduledAt >= start && ($0.scheduledAt <= now || $0.isDone) && !$0.isRecovery }

        var review = CoachReview()
        review.total = week.count
        review.done = week.filter(\.isDone).count
        review.missed = week.filter { $0.isFailed || ($0.isOpen && $0.dueAt < today) }.count
        review.xp = week.filter(\.isDone).map(\.rank.xp).reduce(0, +)
        review.days = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let that = week.filter { calendar.isDate($0.scheduledAt, inSameDayAs: day) }
            return DayTally(date: day, done: that.filter(\.isDone).count, total: that.count)
        }

        // Which part of the day works, and which does not.
        let parts: [(name: String, hours: Range<Int>)] = [("morning", 0..<12), ("afternoon", 12..<18), ("evening", 18..<24)]
        let rates: [(name: String, rate: Double)] = parts.compactMap { part in
            let finished = week.filter { $0.dueAt < now && part.hours.contains(calendar.component(.hour, from: $0.scheduledAt)) }
            guard finished.count >= 3 else { return nil }
            return (part.name, Double(finished.filter(\.isDone).count) / Double(finished.count))
        }
        if let best = rates.max(by: { $0.rate < $1.rate }), let worst = rates.min(by: { $0.rate < $1.rate }),
           best.rate - worst.rate >= 0.15 {
            review.insights.append("You finish \(Int(best.rate * 100))% of \(best.name) quests but only \(Int(worst.rate * 100))% in the \(worst.name).")
        }

        if review.missed > 0 {
            review.insights.append("\(review.missed) quest\(review.missed == 1 ? "" : "s") missed this week.")
        }

        // The stat that is falling behind.
        let weakest = Stat.allCases.min { player.value(for: $0) < player.value(for: $1) } ?? .discipline
        let strongest = Stat.allCases.max { player.value(for: $0) < player.value(for: $1) } ?? .intellect
        review.insights.append("\(weakest.title) is your lowest stat (\(player.value(for: weakest))). \(strongest.title) is your highest (\(player.value(for: strongest))).")
        let soon = min(calendar.component(.hour, from: now) + 1, 22)
        review.suggestions.append(CoachSuggestion(
            title: "Train \(weakest.title) today",
            idea: starter(for: weakest, hour: soon)
        ))

        // The boss that is closest to winning.
        if let boss = bosses.filter({ !$0.isDefeated }).min(by: { $0.deadline < $1.deadline }),
           let task = boss.orderedTasks.first(where: { !$0.isDone }) {
            review.insights.append("\(boss.name): \(boss.remaining) task\(boss.remaining == 1 ? "" : "s") left, \(boss.daysLeft) days.")
            review.suggestions.append(CoachSuggestion(
                title: "Hit \(boss.name)",
                idea: QuestIdea(title: task.title, stat: .discipline, hour: soon, minutes: 45, rank: .c)
            ))
        }
        return review
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
