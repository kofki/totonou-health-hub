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
    /// The two stats added on 2026-11-25, and HP lost. Defaults keep older code compiling.
    var agility: Int = 0
    var charisma: Int = 0
    var damage: Int = 0
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
    /// Titles of what the quest belongs to. Defaults keep older call sites compiling.
    var arc: String? = nil
    var objective: String? = nil
    /// Set on a step: the quest it unlocks, by title and start.
    var parentTitle: String? = nil
    var parentScheduledAt: Date? = nil
    /// The Health or Garmin reading that completes it, and the value to reach.
    var signalKey: String? = nil
    var target: Double? = nil
}

/// An arc, in a shape that can cross the network.
struct ArcRecord: Sendable, Equatable {
    struct ObjectiveRecord: Sendable, Equatable, Encodable {
        var title: String
        var period: String
        var target: Int
        var detail: String
        /// Quest titles from other arcs that also count toward it.
        var sharedQuests: [String] = []
    }

    var title: String
    var kind: String
    var manifesto: String
    var goals: [String]
    var goalsDone: [String]
    var startDate: Date
    /// Nil for an objective arc, which has no end date.
    var endDate: Date?
    var endedAt: Date?
    var questPlan: [String]
    var objectives: [ObjectiveRecord]
}

protocol CloudStore: Sendable {
    /// Make sure someone is signed in. Safe to call more than once.
    func connect() async throws
    func save(profile: ProfileRecord) async throws
    func save(quests: [QuestRecord]) async throws
    func save(arcs: [ArcRecord]) async throws
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
    func save(arcs: [ArcRecord]) async throws {}
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
                                              questsDone: questsDone, autoDone: autoDone, bossesDefeated: bossesDefeated,
                                              agility: agility, charisma: charisma, damage: damage))
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
            agility = rewards.agility
            charisma = rewards.charisma
            damage = rewards.damage
        }
    }
}

extension Quest {
    var record: QuestRecord {
        QuestRecord(title: title, stat: statRaw, rank: rankRaw, source: sourceRaw,
                    isCritical: isCritical, isRecovery: isRecovery, scheduledAt: scheduledAt,
                    durationMinutes: durationMinutes, completedAt: completedAt, failedAt: failedAt,
                    autoCompleted: autoCompleted, arc: arc?.title, objective: objective?.title,
                    parentTitle: parent?.title, parentScheduledAt: parent?.scheduledAt,
                    signalKey: signalKey, target: target)
    }
}

extension Arc {
    var record: ArcRecord {
        ArcRecord(title: title, kind: kindRaw, manifesto: manifesto, goals: goals, goalsDone: goalsDone,
                  startDate: startDate, endDate: kind == .objective ? nil : endDate, endedAt: endedAt,
                  questPlan: questPlan,
                  objectives: orderedObjectives.map {
                      ArcRecord.ObjectiveRecord(title: $0.title, period: $0.periodRaw, target: $0.target, detail: $0.detail,
                                                sharedQuests: $0.sharedTitles)
                  })
    }
}
