import Foundation
import Supabase

/// Where the project lives. The publishable key is meant to ship inside the app:
/// on its own it can do nothing, because row-level security only lets a signed-in
/// user touch their own rows. Never put a secret (service-role) key here.
enum SupabaseConfig {
    static let url = "https://xzxzkbpgcmwogwtkwbqp.supabase.co"
    static let publishableKey = "sb_publishable_eL7t42cOLEohq2Si3i8jIw__H0ZyV8G"

    /// The store the app should use: Supabase when configured, the mock otherwise.
    static func makeStore() -> any CloudStore {
        guard let url = URL(string: url), !publishableKey.isEmpty else { return MockCloudStore() }
        return SupabaseCloudStore(url: url, key: publishableKey)
    }

    static var isConfigured: Bool { URL(string: url) != nil && !publishableKey.isEmpty }
}

/// The real thing: Supabase Auth for "who is this" and Postgres for the rows.
/// Schema: supabase/migrations at the repo root.
final class SupabaseCloudStore: CloudStore {
    private let client: SupabaseClient

    init(url: URL, key: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    /// Signs in anonymously the first time. Supabase keeps the session in the
    /// keychain, so the same device stays the same user between launches.
    /// (Later: Sign in with Apple, so a new phone can get the same account.)
    func connect() async throws {
        if (try? await client.auth.session) != nil { return }
        try await client.auth.signInAnonymously()
    }

    func save(profile: ProfileRecord) async throws {
        let userID = try await client.auth.session.user.id
        try await client.from("profiles")
            .upsert(ProfileRow(userID: userID, profile), onConflict: "user_id")
            .execute()
    }

    func save(quests: [QuestRecord]) async throws {
        guard !quests.isEmpty else { return }
        let userID = try await client.auth.session.user.id
        // Upsert = insert, or update the row that already has this key.
        try await client.from("quests")
            .upsert(quests.map { QuestUpload(userID: userID, $0) }, onConflict: "user_id,scheduled_at,title")
            .execute()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EXERCISE 10 · 復元 · Restore from the cloud        (async/await, Codable)
    //
    // The app saves your profile to Supabase but never reads it back, so a
    // reinstall starts you from the seed data again. Make this function return
    // the profile stored in the cloud. The engine already knows what to do with
    // it (QuestEngine.backUp restores it when the cloud copy has more XP).
    //
    // Steps
    //   1. Read `save(profile:)` above: it shows how to reach the table.
    //   2. Query it: client.from("profiles").select().limit(1).execute()
    //      Row-level security already limits the result to your own row.
    //   3. `ProfileRow` below can only be encoded. Make it `Codable` and decode
    //      the response into `[ProfileRow]`: `.execute().value` does this when
    //      the type you assign it to is Decodable.
    //   4. Turn the first row back into a ProfileRecord. The dates in
    //      completion_days come back as "2026-11-24" strings: `ProfileRow.day`
    //      formats a Date that way, and the same formatter can parse one.
    //   5. No row yet is not an error: return nil.
    //
    // You will practise: async/await with try, Codable and CodingKeys, mapping
    // between a network type and an app type, optionals.
    //
    // How to check: run the app and finish a quest (Status shows "Backed up").
    // In the Supabase table editor, add 500 to your row's total_xp. Relaunch
    // the app: your level on Today should jump. (Deleting the app does not
    // test this: an anonymous sign-in would make you a brand-new user.)
    // ─────────────────────────────────────────────────────────────────────────
    func loadProfile() async throws -> ProfileRecord? {
        // TODO(you): Exercise 10.
        nil
    }
}

// The rows as Postgres spells them. CodingKeys map Swift's camelCase to the
// snake_case column names.

private struct ProfileRow: Encodable, Sendable {
    let userID: UUID
    let name: String
    let totalXP: Int
    let strength: Int
    let endurance: Int
    let intellect: Int
    let discipline: Int
    let recovery: Int
    let bankedMinutes: Int
    let completionDays: [String]
    let updatedAt: String

    init(userID: UUID, _ profile: ProfileRecord) {
        self.userID = userID
        name = profile.name
        totalXP = profile.totalXP
        strength = profile.strength
        endurance = profile.endurance
        intellect = profile.intellect
        discipline = profile.discipline
        recovery = profile.recovery
        bankedMinutes = profile.bankedMinutes
        completionDays = profile.completionDays.map(Self.day)
        updatedAt = Date.now.ISO8601Format()
    }

    /// A Postgres `date`: 2026-11-24, in the device's own time zone.
    static func day(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash).timeZone(separator: .omitted))
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case name
        case totalXP = "total_xp"
        case strength, endurance, intellect, discipline, recovery
        case bankedMinutes = "banked_minutes"
        case completionDays = "completion_days"
        case updatedAt = "updated_at"
    }
}

private struct QuestUpload: Encodable, Sendable {
    let userID: UUID
    let title: String
    let stat: String
    let rank: String
    let source: String
    let isCritical: Bool
    let isRecovery: Bool
    let scheduledAt: String
    let durationMinutes: Int
    let completedAt: String?
    let failedAt: String?
    let autoCompleted: Bool
    let updatedAt: String

    init(userID: UUID, _ quest: QuestRecord) {
        self.userID = userID
        title = quest.title
        stat = quest.stat
        rank = quest.rank
        source = quest.source
        isCritical = quest.isCritical
        isRecovery = quest.isRecovery
        scheduledAt = quest.scheduledAt.ISO8601Format()
        durationMinutes = quest.durationMinutes
        completedAt = quest.completedAt?.ISO8601Format()
        failedAt = quest.failedAt?.ISO8601Format()
        autoCompleted = quest.autoCompleted
        updatedAt = Date.now.ISO8601Format()
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case title, stat, rank, source
        case isCritical = "is_critical"
        case isRecovery = "is_recovery"
        case scheduledAt = "scheduled_at"
        case durationMinutes = "duration_minutes"
        case completedAt = "completed_at"
        case failedAt = "failed_at"
        case autoCompleted = "auto_completed"
        case updatedAt = "updated_at"
    }

    // Write nil as an explicit null, so un-completing a quest clears the column.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userID, forKey: .userID)
        try c.encode(title, forKey: .title)
        try c.encode(stat, forKey: .stat)
        try c.encode(rank, forKey: .rank)
        try c.encode(source, forKey: .source)
        try c.encode(isCritical, forKey: .isCritical)
        try c.encode(isRecovery, forKey: .isRecovery)
        try c.encode(scheduledAt, forKey: .scheduledAt)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(failedAt, forKey: .failedAt)
        try c.encode(autoCompleted, forKey: .autoCompleted)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}
