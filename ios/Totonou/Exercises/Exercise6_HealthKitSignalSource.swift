import Foundation
import HealthKit
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 6 · 実測 · Real data from HealthKit        (async/await, protocols)
//
// Status: handed over to Claude on 2026-11-24 (owner's choice). Solved below.
// Read it as a worked example of the steps that were listed here:
//   1. HealthKit capability and NSHealthShareUsageDescription (Config/Totonou.entitlements
//      and the INFOPLIST_KEY_ build settings).
//   2. One HKHealthStore, read access requested before the first query.
//   3. latest() runs one query per reading, concurrently with `async let`.
//   4. QuestPlanner gives quests a signal from their title (see SignalTarget).
//   5. On the simulator, add data in its Health app to test.
//
// Garmin needs no code of its own: Garmin Connect can write workouts, steps and
// sleep into Apple Health (Garmin Connect → Settings → Apple Health), and they
// arrive here like any other Health data.
// ─────────────────────────────────────────────────────────────────────────────

struct HealthKitSignalSource: SignalSource {
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKObjectType.workoutType(),
        HKCategoryType(.sleepAnalysis),
        HKCategoryType(.mindfulSession),
    ]

    /// HKHealthStore is meant to be created once and shared.
    static let store = HKHealthStore()

    /// Shows the Health permission sheet the first time; after that it returns at once.
    static func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            UserDefaults.standard.set(true, forKey: "healthAsked")
            return true
        } catch {
            return false
        }
    }

    /// Set once you have been asked, from the Connect screen. Until then the
    /// app never reads Health, so the permission sheet never appears uninvited.
    static var wasAsked: Bool { UserDefaults.standard.bool(forKey: "healthAsked") }

    func latest() async throws -> [SignalKey: Double] {
        guard Self.wasAsked, HKHealthStore.isHealthDataAvailable() else { return [:] }
        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)
        // `async let` starts all four queries at once; `await` below waits for each.
        async let steps = Self.sum(.stepCount, unit: .count(), from: startOfDay, to: now)
        async let run = Self.runningKilometres(from: startOfDay, to: now)
        async let mindful = Self.minutes(of: HKCategoryType(.mindfulSession), from: startOfDay, to: now) { _ in true }
        async let sleep = Self.lastNightSleepHours(now: now)

        var readings: [SignalKey: Double] = [:]
        readings[.steps] = try await steps
        readings[.runKm] = try await run
        readings[.focusMinutes] = try await mindful
        readings[.sleepHours] = try await sleep
        return readings
    }

    /// Every workout ever recorded, counted by type. Garmin and other watches
    /// that sync into Apple Health are included.
    func workoutCounts() async throws -> [SkillMeasure: Int] {
        guard Self.wasAsked, HKHealthStore.isHealthDataAvailable() else { return [:] }
        let query = HKSampleQueryDescriptor(predicates: [.workout()], sortDescriptors: [])
        let types = try await query.result(for: Self.store).map(\.workoutActivityType)
        func count(_ kinds: Set<HKWorkoutActivityType>) -> Int { types.filter(kinds.contains).count }
        return [
            .workouts: types.count,
            .cyclingWorkouts: count([.cycling, .handCycling]),
            .swimWorkouts: count([.swimming]),
            .danceWorkouts: count([.socialDance, .cardioDance]),
            .martialArtsWorkouts: count([.martialArts, .boxing, .kickboxing, .wrestling]),
        ]
    }

    private static func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate),
            options: .cumulativeSum
        )
        return try await query.result(for: store)?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    /// Only running workouts count, so a long walk does not finish "Run 5 km".
    private static func runningKilometres(from start: Date, to end: Date) async throws -> Double {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end),
            HKQuery.predicateForWorkouts(with: .running),
        ])
        let query = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
        let workouts = try await query.result(for: store)
        return workouts.compactMap {
            $0.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
        }.reduce(0, +)
    }

    private static func minutes(of type: HKCategoryType, from start: Date, to end: Date,
                                where keep: @escaping @Sendable (HKCategorySample) -> Bool) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [])
        let intervals = try await query.result(for: store).filter(keep).map { DateInterval(start: $0.startDate, end: $0.endDate) }
        return merged(intervals).reduce(0) { $0 + $1.duration } / 60
    }

    /// Sleep from 18:00 yesterday until now, counting only time asleep.
    private static func lastNightSleepHours(now: Date) async throws -> Double {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .hour, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        return try await minutes(of: HKCategoryType(.sleepAnalysis), from: start, to: now) { asleep.contains($0.value) } / 60
    }

    /// A watch and a phone can both record the same night. Merging overlapping
    /// intervals stops that time from being counted twice.
    static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }
}

/// Wakes the app when Health gets new steps, workouts or mindful minutes, so
/// quests can complete while the app is closed. iOS decides the exact timing
/// (steps at most hourly), and nothing arrives after the app is force-quit.
final class HealthWatcher: Sendable {
    static let shared = HealthWatcher()

    func start(onChange: @escaping @Sendable () async -> Void) {
        let store = HealthKitSignalSource.store
        let types: [HKSampleType] = [HKQuantityType(.stepCount), HKObjectType.workoutType(), HKCategoryType(.mindfulSession)]
        for type in types {
            // An observer query does not return data; it only says "something changed".
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                Task {
                    await onChange()
                    // Must be called, or HealthKit backs off and stops waking the app.
                    completion()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
}
