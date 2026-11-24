import Foundation

// The cloud copy of your progress. Like every outside system in this app it sits
// behind a protocol: the engine talks to `CloudStore`, and does not know or care
// whether that is Supabase or a mock that keeps everything in memory.

/// The player, in a shape that can cross the network.
struct ProfileRecord: Sendable, Equatable {
    var name: String
    var totalXP: Int
    var strength: Int
    var endurance: Int
    var intellect: Int
    var discipline: Int
    var recovery: Int
    var bankedMinutes: Int
    var completionDays: [Date]
}

/// One quest, in a shape that can cross the network.
struct QuestRecord: Sendable, Equatable {
    var title: String
    var stat: String
    var rank: String
    var source: String
    var isCritical: Bool
    var isRecovery: Bool
    var scheduledAt: Date
    var durationMinutes: Int
    var completedAt: Date?
    var failedAt: Date?
    var autoCompleted: Bool
}

protocol CloudStore: Sendable {
    /// Make sure someone is signed in. Safe to call more than once.
    func connect() async throws
    func save(profile: ProfileRecord) async throws
    func save(quests: [QuestRecord]) async throws
    /// The profile stored in the cloud, or nil if there is none yet.
    func loadProfile() async throws -> ProfileRecord?
}

/// Keeps everything in memory. Used in previews, and when no project is configured.
actor MockCloudStore: CloudStore {
    private var profile: ProfileRecord?
    private var quests: [QuestRecord] = []

    func connect() async throws {}
    func save(profile: ProfileRecord) async throws { self.profile = profile }
    func save(quests: [QuestRecord]) async throws { self.quests = quests }
    func loadProfile() async throws -> ProfileRecord? { profile }
}

/// What the Status screen says about the backup.
enum CloudState: Equatable {
    /// No project configured: progress lives on this device only.
    case local
    case syncing
    case synced(Date)
    case failed(String)
}

extension Player {
    var record: ProfileRecord {
        ProfileRecord(name: name, totalXP: totalXP, strength: strength, endurance: endurance,
                      intellect: intellect, discipline: discipline, recovery: recovery,
                      bankedMinutes: bankedMinutes, completionDays: completionDays)
    }

    func apply(_ record: ProfileRecord) {
        name = record.name
        totalXP = record.totalXP
        strength = record.strength
        endurance = record.endurance
        intellect = record.intellect
        discipline = record.discipline
        recovery = record.recovery
        bankedMinutes = record.bankedMinutes
        completionDays = record.completionDays
    }
}

extension Quest {
    var record: QuestRecord {
        QuestRecord(title: title, stat: statRaw, rank: rankRaw, source: sourceRaw,
                    isCritical: isCritical, isRecovery: isRecovery, scheduledAt: scheduledAt,
                    durationMinutes: durationMinutes, completedAt: completedAt, failedAt: failedAt,
                    autoCompleted: autoCompleted)
    }
}
