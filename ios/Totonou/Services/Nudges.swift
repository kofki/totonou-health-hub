import Foundation
import TotonouCore

// Notifications made on the phone from what is already in the database: a
// morning summary, an evening count, a warning before a must-do quest is
// missed, a streak-at-risk alert and a reminder of unspent stat points.
// Nothing here is invented: every number comes from your quests and player.

enum Nudges {
    struct Settings: Sendable {
        var daily: Bool
        var streakAndRewards: Bool
    }

    static let morningHour = 8
    static let eveningHour = 20
    static let streakHour = 21

    /// Every nudge from `now` until the end of tomorrow.
    static func items(quests: [Quest], player: Player?, arcs: [Arc], settings: Settings,
                      now: Date = .now) -> [ReminderItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        var items: [ReminderItem] = []

        func at(_ hour: Int, on day: Date) -> Date? {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        }
        let todays = quests.filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) && !$0.isRecovery }
        let open = todays.filter(\.isOpen)

        if settings.daily {
            // Morning: today's count and the first quest. Tomorrow's comes from the plan.
            if let morning = at(morningHour, on: today), morning > now, let first = open.min(by: { $0.scheduledAt < $1.scheduledAt }) {
                items.append(ReminderItem(id: "nudge-morning-today", title: "Today: \(open.count) quest\(open.count == 1 ? "" : "s")",
                                          body: "First up: \(first.title) at \(first.scheduledAt.clock).", at: morning))
            }
            let plan = arcs.dailyPlan(on: tomorrow)
            if let morning = at(morningHour, on: tomorrow), let first = plan.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) {
                items.append(ReminderItem(id: "nudge-morning-tomorrow", title: "Today: \(plan.count) quest\(plan.count == 1 ? "" : "s")",
                                          body: "First up: \(first.title) at \(first.clock).", at: morning))
            }
            // Evening: what is left. Rescheduled whenever a quest is done, so the count stays right.
            if let evening = at(eveningHour, on: today), evening > now, !open.isEmpty {
                items.append(ReminderItem(id: "nudge-evening", title: "\(open.count) quest\(open.count == 1 ? "" : "s") left today",
                                          body: open.prefix(3).map(\.title).joined(separator: ", "), at: evening))
            }
            // Must-do: 30 minutes before it is due, if still open.
            for quest in open where quest.isCritical {
                let warn = quest.dueAt.addingTimeInterval(-30 * 60)
                guard warn > now else { continue }
                items.append(ReminderItem(id: "nudge-mustdo-\(quest.title)-\(Int(quest.scheduledAt.timeIntervalSince1970))",
                                          title: "Must-do: \(quest.title)",
                                          body: "30 minutes left. Missing it sends you to the penalty zone.", at: warn))
            }
        }

        if settings.streakAndRewards, let player {
            // Streak at risk: nothing done today and a streak to lose.
            let streak = player.streak(on: now)
            if streak > 0, !todays.contains(where: \.isDone), let late = at(streakHour, on: today), late > now {
                items.append(ReminderItem(id: "nudge-streak", title: "Your \(streak)-day streak ends tonight",
                                          body: "Finish one quest before midnight to keep it.", at: late))
            }
            // Stat points waiting to be spent.
            if player.unspentStatPoints > 0 {
                let soon = max(now.addingTimeInterval(60 * 60), at(19, on: today) ?? now)
                if calendar.isDate(soon, inSameDayAs: now) {
                    let points = player.unspentStatPoints
                    items.append(ReminderItem(id: "nudge-points", title: "\(points) stat point\(points == 1 ? "" : "s") to spend",
                                              body: "Open Status and put them into a stat.", at: soon))
                }
            }
        }
        return items
    }
}
