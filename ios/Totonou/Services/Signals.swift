import Foundation
import TotonouCore

/// A reading from the outside world that can prove a quest is done.
enum SignalKey: String {
    case steps
    case sleepHours
    case runKm
    case focusMinutes
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
