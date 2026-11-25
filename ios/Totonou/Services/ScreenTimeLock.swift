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
    /// What went wrong last, in words, for the setup screen. Nil when all is well.
    private(set) var problem: String?

    /// Screen Time can report "not decided" for a moment after launch, so the
    /// permission is read again before anything depends on it.
    private func recheck() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// For the setup screen: what iOS says right now.
    var permissionText: String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: "allowed"
        case .denied: "denied (Settings → Screen Time → Apps with Screen Time Access)"
        case .notDetermined: "not asked yet"
        @unknown default: "unknown"
        }
    }

    /// How many apps and categories the lock is applying right now, read back from iOS.
    var shieldedText: String {
        let apps = store.shield.applications?.count ?? 0
        let groups: Int
        if case .specific(let tokens, _) = store.shield.applicationCategories { groups = tokens.count } else { groups = 0 }
        return "\(apps) app\(apps == 1 ? "" : "s"), \(groups) categor\(groups == 1 ? "y" : "ies")"
    }
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
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            problem = nil
        } catch {
            problem = "Screen Time permission failed: \(error.localizedDescription)"
        }
        recheck()
        trackUsage()
    }

    /// Watch how long the chosen apps are used each day, whether or not they
    /// are locked. Midnight to midnight, every day; the monitor writes the
    /// running total (TotonouMonitor.swift).
    func trackUsage() {
        recheck()
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
        do {
            try center.startMonitoring(usageActivity, during: day, events: events)
        } catch {
            problem = "Usage tracking did not start: \(error.localizedDescription)"
        }
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
        recheck()
        if on && !isAuthorized { problem = "Screen Time is not allowed yet. Tap Allow Screen Time first." }
        isOn = on && isAuthorized
        defaults.set(isOn, forKey: "lockOn")
        if isOn { lock() } else { open() }
    }

    /// Spend earned minutes: open the apps now, lock them again in `minutes`.
    func unlock(minutes: Int, now: Date = .now) {
        guard isOn, minutes > 0 else { return }
        var end = now.addingTimeInterval(TimeInterval(minutes * 60))
        // An unlock stops where lock-in hours begin.
        if let hours = lockInHours, !isLockIn(now: now),
           let next = Calendar.current.nextDate(after: now, matching: DateComponents(hour: hours.start, minute: 0),
                                                matchingPolicy: .nextTime), next < end {
            end = next
        }
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
            problem = "Could not schedule the re-lock, so the apps stay locked: \(error.localizedDescription)"
            return
        }
        open()
        unlockedFrom = now
        unlockedUntil = end
        defaults.set(end, forKey: "unlockedUntil")
    }

    /// Close an unlock early: a recovery quest just appeared, or lock-in hours began.
    func endUnlock() {
        center.stopMonitoring([unlockActivity])
        unlockedUntil = nil
        defaults.removeObject(forKey: "unlockedUntil")
        lock()
    }

    // MARK: Lock-in hours

    private let lockInActivity = DeviceActivityName("totonou.lockin")

    /// Hours when earned minutes cannot be spent, e.g. 23 to 7 so late nights
    /// stay off social media. Nil when lock-in is off. Kept in the shared
    /// defaults so the monitor extension can read them.
    var lockInHours: (start: Int, end: Int)? {
        guard defaults.bool(forKey: "lockInOn") else { return nil }
        return (defaults.integer(forKey: "lockInStart"), defaults.integer(forKey: "lockInEnd"))
    }

    func setLockIn(on: Bool, start: Int, end: Int) {
        defaults.set(on, forKey: "lockInOn")
        defaults.set(start, forKey: "lockInStart")
        defaults.set(end, forKey: "lockInEnd")
        center.stopMonitoring([lockInActivity])
        guard on, start != end else { return }
        // Every day from start to end; an end earlier than the start runs past midnight.
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: start, minute: 0),
                                              intervalEnd: DateComponents(hour: end, minute: 0), repeats: true)
        do {
            try center.startMonitoring(lockInActivity, during: schedule)
        } catch {
            problem = "Could not schedule lock-in hours: \(error.localizedDescription)"
        }
        if isLockIn() { endUnlock() }
    }

    /// True during lock-in hours.
    func isLockIn(now: Date = .now) -> Bool {
        guard let hours = lockInHours, hours.start != hours.end else { return false }
        let hour = Calendar.current.component(.hour, from: now)
        return hours.start < hours.end ? (hour >= hours.start && hour < hours.end)
            : (hour >= hours.start || hour < hours.end)
    }

    /// When the current lock-in ends, for the shield screen.
    func lockInEnds(now: Date = .now) -> Date? {
        guard isLockIn(now: now), let hours = lockInHours else { return nil }
        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: hours.end, minute: 0, second: 0, of: now)!
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }

    /// On every launch: lock again if an unlock ran out while the extension did not.
    func refresh(now: Date = .now) {
        recheck()
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
        if hasApps && store.shield.applications == nil && store.shield.applicationCategories == nil && store.shield.webDomains == nil {
            problem = "iOS did not accept the lock. Check that Family Controls is in Signing & Capabilities."
        } else {
            problem = nil
        }
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
