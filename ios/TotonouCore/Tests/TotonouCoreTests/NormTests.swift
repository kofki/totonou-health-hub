import Testing
@testable import TotonouCore

@Suite struct NormTests {
    let vo2 = Norm(id: "vo2", title: "VO2 max", unit: "ml/kg/min", group: .fitness,
                        points: [30, 36, 42, 48, 53, 60], source: "test")
    let restingHR = Norm(id: "rhr", title: "Resting heart rate", unit: "bpm", group: .heart,
                              higherIsBetter: false, points: [80, 74, 66, 60, 54, 46], source: "test")

    @Test func publishedPointsLandOnTheirPercentile() {
        #expect(vo2.percentile(of: 42) == 50)
        #expect(vo2.percentile(of: 53) == 90)
    }

    @Test func betweenPointsIsInterpolated() {
        #expect(vo2.percentile(of: 45) == 62.5)
    }

    @Test func lowerIsBetterTurnsAround() {
        #expect(restingHR.percentile(of: 46) == 99)
        #expect(restingHR.percentile(of: 80) == 10)
        #expect(restingHR.percentile(of: 66) == 50)
    }

    @Test func extremesStayInRange() {
        #expect(vo2.percentile(of: 10) >= 0)
        #expect(vo2.percentile(of: 90) <= 100)
        #expect(restingHR.percentile(of: 30) <= 100)
    }

    @Test func valueAtPercentileIsTheInverse() {
        #expect(vo2.value(atPercentile: 50) == 42)
        #expect(vo2.topOnePercent == 60)
        #expect(restingHR.topOnePercent == 46)
        #expect(restingHR.median == 66)
    }
}

@Suite struct NormCatalogTests {
    @Test func everyNormIsComplete() {
        for norm in NormCatalog.all {
            #expect(norm.points.count == 6, "\(norm.id)")
            // Points run in percentile order: rising when higher is better, falling otherwise.
            let rising = zip(norm.points, norm.points.dropFirst()).allSatisfy { $0 < $1 }
            let falling = zip(norm.points, norm.points.dropFirst()).allSatisfy { $0 > $1 }
            #expect(norm.higherIsBetter ? rising : falling, "\(norm.id)")
            if let athletes = norm.athletePoints {
                let up = zip(athletes, athletes.dropFirst()).allSatisfy { $0 < $1 }
                let down = zip(athletes, athletes.dropFirst()).allSatisfy { $0 > $1 }
                #expect(norm.higherIsBetter ? up : down, "\(norm.id) athletes")
            }
        }
    }

    @Test func bryanJohnsonSitsHighOnHeartRate() {
        let rhr = NormCatalog.norm("restingHeartRate")!
        #expect(rhr.percentile(of: rhr.bryanJohnson!) > 99)
    }

    @Test func athletesAreAHarderCrowd() {
        let bench = NormCatalog.norm("bench")!
        #expect(bench.athletePercentile(of: 1.5)! < bench.percentile(of: 1.5))
    }
}

@Suite struct TestNormTests {
    @Test func aPerfectReflectionScoreIsNearTheTopTenth() {
        let reflection = NormCatalog.norm("reflection")!
        #expect(reflection.percentile(of: 3) > 88)
        #expect(reflection.percentile(of: 0) < 20)
    }

    @Test func iqFollowsTheScale() {
        #expect(NormCatalog.norm("iq")!.percentile(of: 100) == 50)
    }

    @Test func fasterReactionBeatsMorePeople() {
        let reaction = NormCatalog.norm("reactionMs")!
        #expect(reaction.percentile(of: 230) > reaction.percentile(of: 300))
    }
}
