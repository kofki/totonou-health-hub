import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 6 · 実測 · Real data from HealthKit        (async/await, protocols)
//
// Every quest is finished by hand today, because this source reports nothing.
// Make it return real readings from Apple Health, and quests that carry a
// signal (Quest.signalKey and Quest.target) will complete themselves when you
// pull down to refresh on Today. No view needs to change.
//
// Steps
//   1. In Xcode: Totonou target → Signing & Capabilities → + Capability →
//      HealthKit. Add NSHealthShareUsageDescription under the Info tab.
//   2. Create an HKHealthStore and request read access for stepCount,
//      distanceWalkingRunning and sleepAnalysis.
//   3. Implement latest(): query today's step total with
//      HKStatisticsQueryDescriptor (it has an async `result(for:)`), then running
//      distance, then last night's sleep. Return them under the matching SignalKey.
//   4. The engine already uses this source. Give a quest a signal to test
//      with: in QuestPlanner.quests(from:on:arc:), a quest whose title contains
//      "steps" could get signal: .steps, target: 8_000.
//   5. Run on a real phone. The simulator has no health data unless you add
//      some in its Health app.
//
// You will practise: async/await, throwing functions, protocol conformance,
// Sendable, and dependency injection (why the engine takes `any SignalSource`).
//
// Stretch: run the three queries concurrently with `async let`.
// ─────────────────────────────────────────────────────────────────────────────

struct HealthKitSignalSource: SignalSource {
    func latest() async throws -> [SignalKey: Double] {
        // TODO(you): steps 2 and 3.
        return [:]
    }
}
