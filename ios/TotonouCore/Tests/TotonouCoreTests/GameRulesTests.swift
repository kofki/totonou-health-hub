import Foundation
import Testing
@testable import TotonouCore

@Suite struct LevelCurveTests {
    @Test func startsAtLevelOne() {
        #expect(LevelCurve.progress(forTotalXP: 0) == LevelProgress(level: 1, into: 0, needed: 100))
    }

    @Test func levelsUpExactlyOnTheBoundary() {
        #expect(LevelCurve.progress(forTotalXP: 99).level == 1)
        #expect(LevelCurve.progress(forTotalXP: 100) == LevelProgress(level: 2, into: 0, needed: 140))
    }

    @Test func carriesLeftoverXP() {
        // 100 + 140 + 180 + 220 + 260 + 300 = 1200 XP reaches level 7.
        #expect(LevelCurve.progress(forTotalXP: 1340) == LevelProgress(level: 7, into: 140, needed: 340))
    }

    @Test func negativeXPIsTreatedAsZero() {
        #expect(LevelCurve.progress(forTotalXP: -50).level == 1)
    }
}

@Suite struct RankTests {
    @Test func ranksAreOrdered() {
        #expect(Rank.e < Rank.s)
        #expect(Rank.allCases.sorted() == Rank.allCases)
    }

    @Test func harderRanksPayMore() {
        let xp = Rank.allCases.map(\.xp)
        #expect(xp == xp.sorted())
    }

    @Test func noQuestIsFMinus() {
        #expect(!Rank.questRanks.contains(.f))
        #expect(Rank.f.xp == Rank.e.xp)
    }

    @Test func humanRankFollowsLevel() {
        #expect(Rank.forLevel(1) == .f)
        #expect(Rank.forLevel(9) == .f)
        #expect(Rank.forLevel(10) == .e)
        #expect(Rank.forLevel(20) == .d)
        #expect(Rank.forLevel(999) == .s)
    }
}

@Suite struct WordBookTests {
    @Test func sameDaySameWord() {
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(WordBook.word(for: morning) == WordBook.word(for: morning.addingTimeInterval(60)))
    }
}
