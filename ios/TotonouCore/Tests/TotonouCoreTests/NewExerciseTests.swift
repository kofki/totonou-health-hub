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
