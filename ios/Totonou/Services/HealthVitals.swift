import Foundation
import HealthKit
import TotonouCore

// More of what a Garmin watch writes into Apple Health: active calories,
// resting heart rate, heart rate variability and VO2 max. It wraps the
// Exercise 6 source rather than changing it: the steps, runs, sleep and
// mindful minutes still come from there, and these are added on top.

struct HealthVitalsSource: SignalSource {
    let base: any SignalSource

    init(base: any SignalSource = HealthKitSignalSource()) {
        self.base = base
    }

    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.vo2Max),
    ]

    /// Set once these types were asked for, from the Connect screen.
    static let askedKey = "healthVitalsAsked"

    /// Asks for the base types and these together, so it is one Health sheet.
    static func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard await HealthKitSignalSource.requestAccess() else { return false }
        do {
            try await HealthKitSignalSource.store.requestAuthorization(toShare: [], read: readTypes)
            UserDefaults.standard.set(true, forKey: askedKey)
            return true
        } catch {
            return false
        }
    }

    func latest() async throws -> [SignalKey: Double] {
        var readings = try await base.latest()
        guard UserDefaults.standard.bool(forKey: Self.askedKey), HKHealthStore.isHealthDataAvailable() else { return readings }
        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)
        // `async let` runs the four queries at the same time.
        async let calories = Self.sum(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay, to: now)
        async let resting = Self.latest(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 2, now: now)
        async let hrv = Self.latest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 2, now: now)
        async let vo2 = Self.latest(.vo2Max, unit: HKUnit(from: "ml/kg*min"), days: 60, now: now)
        readings[.activeCalories] = try await calories
        // A latest-reading value is left out when there is none, rather than shown as 0.
        readings[.restingHeartRate] = try await resting
        readings[.hrv] = try await hrv
        readings[.vo2Max] = try await vo2
        return readings
    }

    func workoutCounts() async throws -> [SkillMeasure: Int] {
        var counts = try await base.workoutCounts()
        // The sports on top: minutes played and volleyball's branches.
        guard HKHealthStore.isHealthDataAvailable(), !counts.isEmpty else { return counts }
        let query = HKSampleQueryDescriptor(predicates: [.workout()], sortDescriptors: [])
        let sessions = try await query.result(for: HealthKitSignalSource.store).compactMap { workout -> Sport.Session? in
            guard let sport = Self.sport(workout.workoutActivityType) else { return nil }
            return Sport.Session(sport: sport, minutes: Int(workout.duration / 60), start: workout.startDate)
        }
        counts.merge(Sport.facts(sessions)) { $1 }
        return counts
    }

    /// Apple Health's workout types for each sport. Running is left out on purpose.
    static func sport(_ type: HKWorkoutActivityType) -> Sport? {
        switch type {
        case .volleyball: .volleyball
        case .surfingSports: .surf
        case .skatingSports: .skate
        case .snowboarding: .snowboard
        case .downhillSkiing, .crossCountrySkiing: .ski
        case .climbing: .climb
        case .basketball: .basketball
        case .soccer: .soccer
        case .tennis, .badminton, .squash, .racquetball, .tableTennis, .pickleball: .racquet
        case .paddleSports: .paddle
        case .hiking: .hike
        case .yoga: .yoga
        case .golf: .golf
        default: nil
        }
    }

    private static func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum
        )
        return try await query.result(for: HealthKitSignalSource.store)?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    /// The most recent sample from the last `days` days, or nil.
    private static func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, now: Date) async throws -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id), predicate: HKQuery.predicateForSamples(withStart: start, end: now))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try await query.result(for: HealthKitSignalSource.store).first?.quantity.doubleValue(for: unit)
    }
}
