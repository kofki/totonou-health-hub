import Testing
@testable import TotonouCore

@Suite struct HitPointsTests {
    @Test func vitalityAndLevelRaiseMaxHP() {
        #expect(HitPoints.max(vitality: 0, level: 1) == 100)
        #expect(HitPoints.max(vitality: 10, level: 6) == 160)
    }

    @Test func aBadDayIsCapped() {
        let cost = HitPoints.reckoning(misses: [.s, .s, .b], mustDosMissed: 1, sleepHours: 5, sleepScore: 40,
                                       screenMinutesOver: 90)
        #expect(cost == HitPoints.dailyCap)
    }

    @Test func aSmallMissIsSmall() {
        #expect(HitPoints.reckoning(misses: [.e], mustDosMissed: 0, sleepHours: 7.5, sleepScore: 70,
                                    screenMinutesOver: 0) == 2)
    }

    @Test func conditionFollowsHP() {
        #expect(HitPoints.condition(hp: 0, max: 100) == .down)
        #expect(HitPoints.condition(hp: 29, max: 100) == .wounded)
        #expect(HitPoints.condition(hp: 30, max: 100) == .healthy)
    }

    @Test func sleepHealsAndHurts() {
        #expect(HitPoints.healForSleep(hours: 8.2, score: 85) == 15)
        #expect(HitPoints.healForSleep(hours: 7.1, score: nil) == 10)
        #expect(HitPoints.damageForSleep(hours: 5.5, score: nil) == 10)
        #expect(HitPoints.damageForSleep(hours: nil, score: nil) == 0)
    }
}
