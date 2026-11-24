import Foundation

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
}

/// A source with nothing to report. Used in previews and tests.
struct NoSignalSource: SignalSource {
    func latest() async throws -> [SignalKey: Double] { [:] }
}
