import Foundation
import Testing
@testable import TotonouCore

// These tests FAIL on purpose until you finish Exercises 1 and 2.
// Do not edit the tests to make them pass — make the code pass them.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// Noon UTC, `offset` days away from a fixed "today".
private func day(_ offset: Int) -> Date {
    let today = utc.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
    return utc.date(byAdding: .day, value: offset, to: today)!
}

@Suite struct StreakExerciseTests {
    @Test func noCompletionsMeansNoStreak() {
        #expect(StreakCalculator.currentStreak(completionDays: [], today: day(0), calendar: utc) == 0)
    }

    @Test func countsConsecutiveDaysEndingToday() {
        let days = [day(0), day(-1), day(-2)]
        #expect(StreakCalculator.currentStreak(completionDays: days, today: day(0), calendar: utc) == 3)
    }

    @Test func streakSurvivesUntilTodayIsOver() {
        let days = [day(-1), day(-2)]
        #expect(StreakCalculator.currentStreak(completionDays: days, today: day(0), calendar: utc) == 2)
    }

    @Test func aMissedDayBreaksTheStreak() {
        let days = [day(0), day(-1), day(-3), day(-4)]
        #expect(StreakCalculator.currentStreak(completionDays: days, today: day(0), calendar: utc) == 2)
    }

    @Test func aStreakThatEndedTwoDaysAgoIsDead() {
        let days = [day(-2), day(-3)]
        #expect(StreakCalculator.currentStreak(completionDays: days, today: day(0), calendar: utc) == 0)
    }

    @Test func duplicatesAndOrderDoNotMatter() {
        let days = [day(-1), day(0), day(0).addingTimeInterval(3600), day(-1)]
        #expect(StreakCalculator.currentStreak(completionDays: days, today: day(0), calendar: utc) == 2)
    }
}

@Suite struct OverallScoreExerciseTests {
    private func benchmark(_ percentile: Int, _ stat: Stat) -> Benchmark {
        Benchmark(id: UUID().uuidString, title: "", value: "", percentile: percentile, stat: stat)
    }

    @Test func emptyHasNoScore() {
        #expect(BenchmarkScore.overall([]) == nil)
    }

    @Test func plainAverageWhenUnweighted() {
        let score = BenchmarkScore.overall([benchmark(80, .recovery), benchmark(60, .endurance)])
        #expect(score == 70)
    }

    @Test func roundsToNearest() {
        let score = BenchmarkScore.overall([benchmark(80, .recovery), benchmark(61, .endurance)])
        #expect(score == 71) // 70.5 rounds up
    }

    @Test func weightsShiftTheAverage() {
        let score = BenchmarkScore.overall(
            [benchmark(90, .endurance), benchmark(30, .strength)],
            weights: [.endurance: 3] // strength falls back to weight 1
        )
        #expect(score == 75)
    }

    @Test func allZeroWeightsHaveNoScore() {
        let score = BenchmarkScore.overall([benchmark(90, .endurance)], weights: [.endurance: 0])
        #expect(score == nil)
    }
}
