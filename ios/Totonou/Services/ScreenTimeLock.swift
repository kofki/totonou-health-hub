import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation
import TotonouCore

// The Screen Time lock: apps you choose stay locked, and spending earned
// minutes opens them for that long. It uses Apple's Screen Time API on your
// own phone ("individual" authorization), so only you can switch it off, from
// here. Re-locking when the time is up happens in the TotonouMonitor
// extension, because by then Totonou is usually closed.
//
// Apple keeps which apps you picked private: the app only ever holds opaque
// tokens, never the app names.

@MainActor
@Observable
final class ScreenTimeLock {
    static let shared = ScreenTimeLock()

    private let defaults = UserDefaults(suiteName: WidgetSnapshot.groupID) ?? .standard
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("totonou"))
    private let center = DeviceActivityCenter()
    private let unlockActivity = DeviceActivityName("totonou.unlock")
    private let usageActivity = DeviceActivityName("totonou.usage")

    /// Usage steps the monitor is told about: every 15 minutes to 4 hours, then
    /// every hour to 8. Each one fires once a day when reached.
    static let usageSteps: [Int] = Array(stride(from: 15, through: 240, by: 15)) + [300, 360, 420, 480]

    private(set) var isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    private(set) var isOn: Bool
    private(set) var unlockedUntil: Date?
    /// When the current unlock started, for a countdown bar.
    private(set) var unlockedFrom: Date?
    var selection: FamilyActivitySelection {
        didSet { save() }
    }

    private init() {
        isOn = defaults.bool(forKey: "lockOn")
        let until = defaults.object(forKey: "unlockedUntil") as? Date
        unlockedUntil = until.flatMap { $0 > .now ? $0 : nil }
        selection = defaults.data(forKey: "lockSelection")
            .flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) } ?? FamilyActivitySelection()
    }

    var hasApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    /// Shows Apple's Screen Time permission sheet. Needs Face ID or the passcode.
    func authorize() async {
        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        trackUsage()
    }

    /// Watch how long the chosen apps are used each day, whether or not they
    /// are locked. Midnight to midnight, every day; the monitor writes the
    /// running total (TotonouMonitor.swift).
    func trackUsage() {
        guard isAuthorized, hasApps else {
            center.stopMonitoring([usageActivity])
            return
        }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minutes in Self.usageSteps {
            events[DeviceActivityEvent.Name("usage-\(minutes)")] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes))
        }
        let day = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                         intervalEnd: DateComponents(hour: 23, minute: 59),
                                         repeats: true)
        center.stopMonitoring([usageActivity])
        try? center.startMonitoring(usageActivity, during: day, events: events)
    }

    /// Minutes the chosen apps were used today, in 15-minute steps (at least
    /// this much), or nil when usage is not being tracked. Readable from any thread.
    /// Finished days, "2026-11-24": minutes, newest last. Up to 60 days.
    nonisolated static func usageHistory() -> [(day: String, minutes: Int)] {
        let history = UserDefaults(suiteName: WidgetSnapshot.groupID)?.dictionary(forKey: "usageHistory") as? [String: Int] ?? [:]
        return history.sorted { $0.key < $1.key }.map { (day: $0.key, minutes: $0.value) }
    }

    nonisolated static func usageToday(now: Date = .now) -> Int? {
        let defaults = UserDefaults(suiteName: WidgetSnapshot.groupID)
        guard AuthorizationCenter.shared.authorizationStatus == .approved,
              let day = defaults?.object(forKey: "usageDay") as? Date else { return nil }
        return Calendar.current.isDate(day, inSameDayAs: now) ? defaults?.integer(forKey: "usageMinutes") : 0
    }

    func setOn(_ on: Bool) {
        isOn = on && isAuthorized
        defaults.set(isOn, forKey: "lockOn")
        if isOn { lock() } else { open() }
    }

    /// Spend earned minutes: open the apps now, lock them again in `minutes`.
    func unlock(minutes: Int, now: Date = .now) {
        guard isOn, minutes > 0 else { return }
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        // Apple's shortest monitored window is 15 minutes. A shorter unlock (an
        // emergency pass) starts the window in the past, so it still ends on time.
        let start = min(now, end.addingTimeInterval(-15 * 60))
        let calendar = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: calendar.dateComponents(parts, from: start),
                                              intervalEnd: calendar.dateComponents(parts, from: end),
                                              repeats: false)
        center.stopMonitoring([unlockActivity])
        do {
            try center.startMonitoring(unlockActivity, during: schedule)
        } catch {
            // Without the window nothing would lock again, so keep the apps locked.
            return
        }
        open()
        unlockedFrom = now
        unlockedUntil = end
        defaults.set(end, forKey: "unlockedUntil")
    }

    /// On every launch: lock again if an unlock ran out while the extension did not.
    func refresh(now: Date = .now) {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        guard isOn else { return }
        if let until = unlockedUntil, until > now { return }
        unlockedUntil = nil
        defaults.removeObject(forKey: "unlockedUntil")
        lock()
    }

    private func lock() {
        guard isOn else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func open() {
        store.clearAllSettings()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(selection) { defaults.set(data, forKey: "lockSelection") }
        if isOn && unlockedUntil == nil { lock() }
        // New apps chosen: watch those instead.
        trackUsage()
    }
}
