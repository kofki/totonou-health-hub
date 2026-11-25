import Foundation
import Testing
@testable import TotonouCore

@Suite struct SportTests {
    @Test func garminTypesMapToSports() {
        #expect(Sport.from(garminType: "volleyball") == .volleyball)
        #expect(Sport.from(garminType: "beach_volleyball") == .volleyball)
        #expect(Sport.from(garminType: "resort_snowboarding") == .snowboard)
        #expect(Sport.from(garminType: "inline_skating") == .skate)
        #expect(Sport.from(garminType: "skate_skiing_ws") == .ski)
        #expect(Sport.from(garminType: "running") == nil)
    }

    @Test func volleyballBranchesAddUp() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let facts = Sport.facts([
            .init(sport: .volleyball, minutes: 90, start: now.addingTimeInterval(-2 * 86_400)),
            .init(sport: .volleyball, minutes: 60, start: now.addingTimeInterval(-40 * 86_400)),
            .init(sport: .surf, minutes: 45, start: now),
        ], now: now)
        #expect(facts[.volleyballMinutes] == 150)
        #expect(facts[.volleyballSessions] == 2)
        #expect(facts[.volleyballLongest] == 90)
        #expect(facts[.volleyballRecent] == 1)
        #expect(facts[.surfMinutes] == 45)
    }

    @Test func sportSkillsHaveRankNames() {
        let volleyball = SkillCatalog.builtIn.first { $0.id == "volleyball" }!
        #expect(volleyball.rank([.volleyballMinutes: 200]) == "Rookie")
        #expect(volleyball.rank([:]) == nil)
        #expect(SkillCatalog.valid(SkillCatalog.builtIn).count == SkillCatalog.builtIn.count)
    }

    @Test func branchesFollowTheirSkill() {
        let tree = SkillTree.ordered(SkillCatalog.builtIn, facts: [.volleyballMinutes: 120, .volleyballSessions: 2])
        let index = tree.firstIndex { $0.skill.id == "volleyball" }!
        let branches = tree[(index + 1)...].prefix { $0.isBranch }.map(\.skill.id)
        #expect(Set(branches) == ["courtRegular", "endlessRally", "inSeason"])
        #expect(tree.count == SkillCatalog.builtIn.count)
        #expect(tree.first?.skill.id == "volleyball" || tree.first?.skill.level([.volleyballMinutes: 120]) ?? 0 > 0)
    }
}
