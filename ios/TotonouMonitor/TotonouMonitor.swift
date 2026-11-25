import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import TotonouCore

// Runs in the background, without the app open. iOS starts it itself
// (Config/TotonouMonitor-Info.plist says which class); the app only schedules
// what it watches (ScreenTimeLock.swift). Two jobs:
//   1. When an unlock you paid for with earned minutes ends, lock the chosen
//      apps again ("totonou.unlock").
//   2. Each time the chosen apps reach another 15 minutes of use today, write
//      the new total where the app can read it ("totonou.usage"). Apple never
//      gives apps usage numbers directly; these steps are what it allows.

final class TotonouMonitor: DeviceActivityMonitor {
    private let defaults = UserDefaults(suiteName: WidgetSnapshot.groupID)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // A new day of tracking: start counting from zero.
        if activity.rawValue == "totonou.usage" { record(minutes: 0) }
        // Lock-in hours begin: shut the apps even if minutes were being spent.
        if activity.rawValue == "totonou.lockin" { shield() }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == "totonou.unlock" else { return }
        shield()
    }

    /// Put the chosen apps behind the shield, if the lock is switched on in the app.
    private func shield() {
        guard defaults?.bool(forKey: "lockOn") == true,
              let data = defaults?.data(forKey: "lockSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("totonou"))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        defaults?.removeObject(forKey: "unlockedUntil")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // Events are named "usage-<minutes>".
        guard activity.rawValue == "totonou.usage",
              let minutes = Int(event.rawValue.replacingOccurrences(of: "usage-", with: "")) else { return }
        record(minutes: minutes)
    }

    /// Today's total, never going down within a day.
    private func record(minutes: Int) {
        let today = Calendar.current.startOfDay(for: .now)
        let lastDay = defaults?.object(forKey: "usageDay") as? Date
        let sameDay = lastDay.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false
        // A new day: file the finished day's total into the history first.
        if let lastDay, !sameDay {
            var history = defaults?.dictionary(forKey: "usageHistory") as? [String: Int] ?? [:]
            history[Self.key(lastDay)] = defaults?.integer(forKey: "usageMinutes") ?? 0
            // Keep 60 days.
            let cutoff = Self.key(Calendar.current.date(byAdding: .day, value: -60, to: today) ?? today)
            history = history.filter { $0.key >= cutoff }
            defaults?.set(history, forKey: "usageHistory")
        }
        let current = sameDay ? (defaults?.integer(forKey: "usageMinutes") ?? 0) : 0
        defaults?.set(minutes == 0 ? 0 : max(current, minutes), forKey: "usageMinutes")
        defaults?.set(today, forKey: "usageDay")
        defaults?.set(Date.now, forKey: "usageUpdatedAt")
    }

    /// "2026-11-25": sorts by date as text.
    static func key(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
