import Foundation
import TotonouCore

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
    /// Reward progress. Optional with a default, so code that builds a record
    /// without it (Exercise 10) still compiles.
    var rewards: ProfileRewards? = nil
}

/// The reward fields of a profile (supabase/migrations/20261124120000_rewards.sql).
struct ProfileRewards: Sendable, Equatable {
    var unspentStatPoints: Int
    var streakFreezes: Int
    var frozenDays: [Date]
    var emergencyPasses: Int
    var titles: [String]
    var activeTitle: String?
    var achievements: [String]
    var clearDays: [Date]
    var questsDone: Int
    var autoDone: Int
    var bossesDefeated: Int
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
    /// The skill catalogue (the `skills` table). Readable by everyone signed in.
    func loadSkills() async throws -> [SkillDefinition]
    /// Delete every quest stored in the cloud for this user (Reset progress).
    func eraseQuests() async throws
}

/// Keeps everything in memory. Used in previews, and when no project is configured.
actor MockCloudStore: CloudStore {
    private var profile: ProfileRecord?
    private var quests: [QuestRecord] = []

    func connect() async throws {}
    func save(profile: ProfileRecord) async throws { self.profile = profile }
    func save(quests: [QuestRecord]) async throws { self.quests = quests }
    func loadProfile() async throws -> ProfileRecord? { profile }
    func loadSkills() async throws -> [SkillDefinition] { [] }
    func eraseQuests() async throws { quests = [] }
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
                      bankedMinutes: bankedMinutes, completionDays: completionDays,
                      rewards: ProfileRewards(unspentStatPoints: unspentStatPoints, streakFreezes: streakFreezes,
                                              frozenDays: frozenDays, emergencyPasses: emergencyPasses, titles: titles,
                                              activeTitle: activeTitle, achievements: achievementsRaw, clearDays: clearDays,
                                              questsDone: questsDone, autoDone: autoDone, bossesDefeated: bossesDefeated))
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
        if let rewards = record.rewards {
            unspentStatPoints = rewards.unspentStatPoints
            streakFreezes = rewards.streakFreezes
            frozenDays = rewards.frozenDays
            emergencyPasses = rewards.emergencyPasses
            titles = rewards.titles
            activeTitle = rewards.activeTitle
            achievementsRaw = rewards.achievements
            clearDays = rewards.clearDays
            questsDone = rewards.questsDone
            autoDone = rewards.autoDone
            bossesDefeated = rewards.bossesDefeated
        }
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
