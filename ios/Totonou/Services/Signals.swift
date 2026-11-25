import Foundation
import TotonouCore

/// A reading from the outside world that can prove a quest is done.
enum SignalKey: String {
    case steps
    case sleepHours
    case runKm
    case focusMinutes
    /// Active calories burned today, kcal.
    case activeCalories
    // Readings for the coach and Claude, not quest targets: lower is better
    // for some, so "reach this value" does not fit. Garmin and other watches
    // fill them in through Apple Health (HealthVitals.swift).
    /// Resting heart rate, beats per minute, the latest reading.
    case restingHeartRate
    /// Heart rate variability (SDNN), milliseconds, the latest reading.
    case hrv
    /// VO2 max, ml/kg/min, the latest estimate.
    case vo2Max
    // From Garmin only (GarminSource.swift).
    /// Body Battery, 0-100, the latest value.
    case bodyBattery
    /// Average stress for the day, 0-100.
    case stress
    /// Last night's sleep score, 0-100.
    case sleepScore
    /// Minutes the apps chosen for the Screen Time lock were used today, in
    /// 15-minute steps (ScreenTimeLock.swift). Lower is better.
    case screenMinutes
}

/// Anything that can report today's readings: Garmin, HealthKit, Google Calendar.
/// The app only ever talks to this protocol, so swapping the mock for the real
/// thing later does not touch a single view.
protocol SignalSource: Sendable {
    func latest() async throws -> [SignalKey: Double]
    /// All-time workout counts by type, for the workout skills.
    func workoutCounts() async throws -> [SkillMeasure: Int]
}

extension SignalSource {
    /// Sources without workouts report none.
    func workoutCounts() async throws -> [SkillMeasure: Int] { [:] }
}

/// Reads a quest title for something Health can prove: "8,000 steps",
/// "Run 5 km", "Meditate 10 min". Titles it does not recognise stay manual.
enum SignalTarget {
    static func guess(from title: String) -> (key: SignalKey, target: Double)? {
        let text = title.lowercased()
        if text.contains("step") {
            return (.steps, number(before: "step", in: text) ?? 8_000)
        }
        if text.contains("run") && !text.contains("brun") {
            return (.runKm, number(before: "k", in: text) ?? 3)
        }
        if text.contains("kcal") || text.contains("calorie") {
            return (.activeCalories, number(before: "kcal", in: text) ?? number(before: "cal", in: text) ?? 400)
        }
        if ["meditat", "mindful", "breath"].contains(where: text.contains) {
            return (.focusMinutes, number(before: "min", in: text) ?? 10)
        }
        return nil
    }

    /// The number written just before a word: "8,000 steps" → 8000, "5 km" → 5, "8k steps" → 8000.
    private static func number(before word: String, in text: String) -> Double? {
        guard let match = try? Regex(#"(\d[\d,\.]*)\s*(k)?\s*"# + word).firstMatch(in: text),
              let digits = match.output[1].substring,
              let value = Double(digits.replacingOccurrences(of: ",", with: "")) else { return nil }
        let thousand = match.output[2].substring != nil && word != "k"
        return thousand ? value * 1_000 : value
    }
}

/// A source with nothing to report. Used in previews and tests.
struct NoSignalSource: SignalSource {
    func latest() async throws -> [SignalKey: Double] { [:] }
}
