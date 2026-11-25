import Foundation
import SwiftData
import TotonouCore

/// Starting over. Progress goes back to zero on the phone and in the cloud;
/// what you planned (arcs, objectives, plans, bosses) stays.
enum ProgressReset {
    /// Set while the cloud still holds the old progress. `backUp` reads it so a
    /// failed upload cannot bring the old XP back at the next launch.
    static let pendingKey = "progressResetPending"
}

extension QuestEngine {
    /// Level, XP, stats, stat points, streak, screen-time minutes, rewards,
    /// achievements, skills and quest history go back to zero. Open quests from
    /// today on stay, so today's plan is still there.
    func resetProgress(context: ModelContext, now: Date = .now) async {
        UserDefaults.standard.set(true, forKey: ProgressReset.pendingKey)

        // A brand-new player rather than zeroing each field by hand, so a field
        // added later cannot be forgotten here. Only the name carries over.
        let players = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        let name = players.first?.name ?? "Human"
        for player in players { context.delete(player) }
        let fresh = Player(name: name)
        context.insert(fresh)

        // Quest history: anything finished, failed, or from an earlier day.
        let today = Calendar.current.startOfDay(for: now)
        for quest in (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        where !quest.isOpen || quest.scheduledAt < today {
            if let id = quest.alarmID { alarms.cancel(id: id) }
            context.delete(quest)
        }
        try? context.save()
        claudeApplied = nil

        // Today's plan again, for any arc whose quests today were all finished.
        Bootstrap.rollDailyQuests(context, now: now)
        try? context.save()

        // The cloud: drop the old history, then save the fresh profile and today.
        let remaining = (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        let todays = remaining.filter { Calendar.current.isDate($0.scheduledAt, inSameDayAs: now) }
        try? await cloud.eraseQuests()
        await backUp(player: fresh, quests: todays)
        publishWidget(player: fresh, quests: todays)
        await shareWithClaude(context: context, now: now)
    }
}
