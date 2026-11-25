import Foundation
import Supabase
import TotonouCore

// Garmin Connect, through the `garmin` Edge Function and Garmin's Personal API
// (supabase/functions/garmin). The function holds the Garmin key; the app only
// asks it for today's numbers. On top of what Apple Health already has, Garmin
// adds Body Battery, stress and the sleep score, and its own HRV and resting
// heart rate, which are preferred over Health's copies.

struct GarminSource: SignalSource {
    let base: any SignalSource

    init(base: any SignalSource = HealthVitalsSource()) {
        self.base = base
    }

    /// Set after Garmin answers once, so Connect can show it as connected.
    static let worksKey = "garminWorks"

    private struct Request: Encodable { let date: String }
    private struct Answer: Decodable {
        let readings: [String: Double?]
    }

    func latest() async throws -> [SignalKey: Double] {
        var readings = (try? await base.latest()) ?? [:]
        // Screen Time is not Health or Garmin, but it is read at the same moment.
        if let minutes = ScreenTimeLock.usageToday() { readings[.screenMinutes] = Double(minutes) }
        guard let garmin = await Self.today() else { return readings }
        for (key, value) in garmin {
            switch key {
            // Health already counts these from the same watch; keep the larger so nothing is counted twice.
            case .steps, .sleepHours, .activeCalories:
                readings[key] = max(readings[key] ?? 0, value)
            default:
                readings[key] = value
            }
        }
        return readings
    }

    func workoutCounts() async throws -> [SkillMeasure: Int] {
        try await base.workoutCounts()
    }

    /// Today's Garmin readings, or nil when Garmin is not set up or did not answer.
    static func today(now: Date = .now) async -> [SignalKey: Double]? {
        guard let client = SupabaseConfig.client, (try? await client.auth.session) != nil else { return nil }
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        do {
            let answer: Answer = try await client.functions.invoke("garmin", options: FunctionInvokeOptions(body: Request(date: date)))
            UserDefaults.standard.set(true, forKey: worksKey)
            var readings: [SignalKey: Double] = [:]
            for (name, value) in answer.readings {
                if let value, let key = SignalKey(rawValue: name) { readings[key] = value }
            }
            return readings
        } catch {
            return nil
        }
    }
}
