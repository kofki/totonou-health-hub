import Foundation
import Testing
@testable import TotonouCore

// These tests FAIL on purpose until you finish Exercises 12 and 14.
// Do not edit the tests to make them pass — make the code pass them.

@Suite struct NextMilestoneExerciseTests {
    @Test func fromZeroTheFirstChestIsThreeDaysAway() {
        let next = NextMilestone.after(streak: 0)
        #expect(next?.milestone.days == 3)
        #expect(next?.daysLeft == 3)
    }

    @Test func reachingAMilestonePointsAtTheNextOne() {
        #expect(NextMilestone.after(streak: 7)?.milestone.days == 14)
        #expect(NextMilestone.after(streak: 8)?.daysLeft == 6)
    }

    @Test func pastTheLastMilestoneThereIsNone() {
        #expect(NextMilestone.after(streak: 100) == nil)
        #expect(NextMilestone.after(streak: 250) == nil)
    }

    @Test func negativeCountsAsZero() {
        #expect(NextMilestone.after(streak: -4)?.daysLeft == 3)
    }
}

@Suite struct BusyFilterExerciseTests {
    private func event(allDay: Bool = false, availability: CalendarEventInfo.Availability = .busy, declined: Bool = false) -> CalendarEventInfo {
        CalendarEventInfo(id: "1", title: "Event", start: .now, end: .now.addingTimeInterval(3600),
                          isAllDay: allDay, availability: availability, isDeclined: declined)
    }

    @Test func aNormalMeetingIsBusy() { #expect(BusyFilter.isBusy(event())) }
    @Test func tentativeIsBusy() { #expect(BusyFilter.isBusy(event(availability: .tentative))) }
    @Test func allDayIsNotBusy() { #expect(!BusyFilter.isBusy(event(allDay: true))) }
    @Test func freeIsNotBusy() { #expect(!BusyFilter.isBusy(event(availability: .free))) }
    @Test func declinedIsNotBusy() { #expect(!BusyFilter.isBusy(event(declined: true))) }
}

// Fails on purpose until you finish Exercise 16.
@Suite struct PlanMergerExerciseTests {
    private struct Slot: DailySlot, Equatable {
        var title: String
        var hour: Int
        var minute: Int = 0
    }

    @Test func slotsComeOutInTimeOrder() {
        let merged = PlanMerger.merged([
            [Slot(title: "Run", hour: 18), Slot(title: "Wake", hour: 6, minute: 30)],
            [Slot(title: "Read", hour: 6, minute: 15), Slot(title: "Lights out", hour: 22)],
        ])
        #expect(merged.map(\.title) == ["Read", "Wake", "Run", "Lights out"])
    }

    @Test func aRepeatedTitleKeepsOnlyTheEarliest() {
        let merged = PlanMerger.merged([
            [Slot(title: "Read 20 min", hour: 21)],
            [Slot(title: " read 20 MIN ", hour: 7), Slot(title: "Run", hour: 8)],
        ])
        #expect(merged == [Slot(title: " read 20 MIN ", hour: 7), Slot(title: "Run", hour: 8)])
    }

    @Test func slotsAtTheSameTimeKeepTheirOrder() {
        let merged = PlanMerger.merged([
            [Slot(title: "Stretch", hour: 7)],
            [Slot(title: "Journal", hour: 7), Slot(title: "Water", hour: 7)],
        ])
        #expect(merged.map(\.title) == ["Stretch", "Journal", "Water"])
    }

    @Test func noPlansGiveAnEmptyList() {
        #expect(PlanMerger.merged([[Slot]]()).isEmpty)
        #expect(PlanMerger.merged([[Slot](), []]).isEmpty)
    }
}
