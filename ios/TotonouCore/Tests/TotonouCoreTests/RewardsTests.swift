import Foundation
import Testing
@testable import TotonouCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func day(_ offset: Int) -> Date {
    let today = utc.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
    return utc.date(byAdding: .day, value: offset, to: today)!
}

@Suite struct LevelRewardTests {
    @Test func everyLevelPaysAPointAndMinutes() {
        let reward = Rewards.forLevel(7)
        #expect(reward.statPoints == 1)
        #expect(reward.minutes == 10)
        #expect(reward.title == nil)
        #expect(!reward.isRankUp)
    }

    @Test func everyFifthLevelGivesATitle() {
        #expect(Rewards.forLevel(5).title == "Awakened")
        #expect(Rewards.forLevel(15).title == "Early Riser")
        #expect(Rewards.forLevel(55).title == "Legend 55")
    }

    @Test func rankUpsGiveAFreezeAndAPass() {
        let reward = Rewards.forLevel(20)
        #expect(reward.isRankUp)
        #expect(reward.freezes == 1)
        #expect(reward.passes == 1)
        #expect(!Rewards.forLevel(60).isRankUp)
    }

    @Test func crossingSeveralLevelsPaysEachOne() {
        #expect(Rewards.rewards(from: 3, to: 6).map(\.level) == [4, 5, 6])
        #expect(Rewards.rewards(from: 6, to: 6).isEmpty)
    }

    @Test func masteryAddsFivePercentPerTenPoints() {
        #expect(Rewards.questXP(rank: .c, statValue: 9) == 35)
        #expect(Rewards.questXP(rank: .c, statValue: 10) == 37)
        #expect(Rewards.questXP(rank: .s, statValue: 40) == 240)
        #expect(Rewards.questXP(rank: .e, statValue: -5) == 10)
    }

    @Test func nextTitle() {
        #expect(Titles.next(after: 15).level == 20)
        #expect(Titles.next(after: 15).title == "Iron Will")
        #expect(Titles.next(after: 17).level == 20)
    }
}

@Suite struct StreakRewardTests {
    @Test func milestonesOpenOnTheirDay() {
        #expect(StreakMilestones.reached(streak: 7)?.freezes == 1)
        #expect(StreakMilestones.reached(streak: 8) == nil)
    }

    @Test func frozenDaysKeepTheStreak() {
        let done = [day(0), day(-2), day(-3)]
        let frozen = [day(-1)]
        #expect(StreakCalculator.currentStreak(completionDays: done + frozen, today: day(0), calendar: utc) == 4)
    }

    @Test func aFreezeCoversOneMissedDay() {
        let days = StreakFreeze.daysToFreeze(completionDays: [day(-2), day(-3)], frozenDays: [], available: 1, today: day(0), calendar: utc)
        #expect(days == [utc.startOfDay(for: day(-1))])
    }

    @Test func noFreezeNeededWhenYesterdayCounts() {
        let days = StreakFreeze.daysToFreeze(completionDays: [day(-1)], frozenDays: [], available: 2, today: day(0), calendar: utc)
        #expect(days.isEmpty)
    }

    @Test func notEnoughFreezesSavesNothing() {
        let days = StreakFreeze.daysToFreeze(completionDays: [day(-4)], frozenDays: [], available: 2, today: day(0), calendar: utc)
        #expect(days.isEmpty)
    }

    @Test func noStreakToSave() {
        #expect(StreakFreeze.daysToFreeze(completionDays: [], frozenDays: [], available: 2, today: day(0), calendar: utc).isEmpty)
    }
}

@Suite struct AchievementTests {
    @Test func nothingDoneEarnsNothing() {
        #expect(AchievementFacts().earned.isEmpty)
    }

    @Test func thresholds() {
        let facts = AchievementFacts(questsDone: 100, autoDone: 1, streak: 7, level: 20)
        let earned = facts.earned
        #expect(earned.isSuperset(of: [.firstQuest, .quests100, .firstAuto, .streak7, .level10, .rankC]))
        #expect(!earned.contains(.streak30))
    }
}

@Suite struct DayPlannerTests {
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: hour, minute: minute))!
    }

    @Test func freeTimeStaysPut() {
        #expect(DayPlanner.firstFreeStart(at: at(10), minutes: 30, busy: [], dayEnd: at(23)) == at(10))
    }

    @Test func movesPastOverlappingBlocks() {
        let busy = [DateInterval(start: at(9, 30), end: at(11)), DateInterval(start: at(9), end: at(10))]
        #expect(DayPlanner.firstFreeStart(at: at(9), minutes: 30, busy: busy, dayEnd: at(23)) == at(11))
    }

    @Test func givesUpWhenTheDayIsFull() {
        let busy = [DateInterval(start: at(20), end: at(23))]
        #expect(DayPlanner.firstFreeStart(at: at(21), minutes: 30, busy: busy, dayEnd: at(23)) == nil)
    }
}
