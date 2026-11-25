import Foundation

// Hit points: how well you are holding up. Finishing what you planned is the
// main way back up; missing it, a short night and going over your screen-time
// limit take HP away. At 0 you are in the penalty zone until a recovery quest
// is done.
//
// Penalties never compound (owner's request, 2026-11-25): one morning's misses
// cost at most `dailyCap`, and a morning brings one recovery quest however
// much was missed.

public enum HitPoints {
    /// 100 to start, more with Vitality and level, so a stronger character takes more hits.
    public static func max(vitality: Int, level: Int) -> Int {
        100 + 5 * Swift.max(vitality, 0) + 2 * Swift.max(level - 1, 0)
    }

    // What heals. Finishing things is the main source.
    /// Every finished quest: 1 for rank E up to 6 for rank S.
    public static func healForQuest(rank: Rank) -> Int { rank.statPoints }
    /// Every quest of one arc done for the day.
    public static let healForClearedArc = 20
    /// The morning's recovery quest.
    public static let healForRecovery = 15
    /// A real night: 7 hours or more. A great one (8 h and a sleep score of 80+) heals more.
    public static func healForSleep(hours: Double?, score: Double?) -> Int {
        guard let hours else { return 0 }
        if hours >= 8, (score ?? 0) >= 80 { return 15 }
        return hours >= 7 ? 10 : 0
    }

    // What hurts.
    /// A quest that ran out without being done: 2 for rank E up to 20 for rank S.
    public static func damageForMiss(rank: Rank) -> Int {
        switch rank {
        case .f, .e: 2
        case .d: 4
        case .c: 6
        case .b: 10
        case .a: 15
        case .s: 20
        }
    }
    /// A missed must-do.
    public static let damageForMustDo = 25
    /// Under 6 hours, or a sleep score under 60.
    public static func damageForSleep(hours: Double?, score: Double?) -> Int {
        guard let hours else { return 0 }
        return hours < 6 || (score.map { $0 < 60 } ?? false) ? 10 : 0
    }
    /// Every 30 minutes past the screen-time limit on the locked apps.
    public static func damageForScreen(minutesOver: Int) -> Int { 5 * Swift.max(minutesOver, 0) / 30 }
    /// The most one morning's reckoning can take, so a bad day is an L, not a spiral.
    public static let dailyCap = 40

    /// Under this share of max HP you are wounded: quests pay half XP.
    public static let woundedShare = 0.3

    public enum Condition: Equatable, Sendable {
        case healthy, wounded, down
    }

    public static func condition(hp: Int, max: Int) -> Condition {
        if hp <= 0 { return .down }
        return Double(hp) < Double(max) * woundedShare ? .wounded : .healthy
    }

    /// What yesterday cost, capped. `misses` are the ranks of quests that ran out.
    public static func reckoning(misses: [Rank], mustDosMissed: Int, sleepHours: Double?, sleepScore: Double?,
                                 screenMinutesOver: Int) -> Int {
        let total = misses.map(damageForMiss).reduce(0, +) + mustDosMissed * damageForMustDo
            + damageForSleep(hours: sleepHours, score: sleepScore) + damageForScreen(minutesOver: screenMinutesOver)
        return Swift.min(total, dailyCap)
    }
}
