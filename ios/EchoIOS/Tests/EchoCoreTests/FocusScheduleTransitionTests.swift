import XCTest
@testable import EchoCore

final class FocusScheduleTransitionTests: XCTestCase {
    func testDisableAlwaysStopsMonitoringEvenWhenEditedWindowIsInvalid() {
        let invalidWindow = DailyFocusWindow(startMinute: 10 * 60, endMinute: 10 * 60)
        let transition = FocusScheduleTransition(requestedEnabled: false, window: invalidWindow)

        XCTAssertTrue(transition.shouldStopMonitoring)
        XCTAssertFalse(transition.canStartMonitoring)
    }

    func testEnableRequiresAValidWindow() {
        let validWindow = DailyFocusWindow(startMinute: 22 * 60, endMinute: 7 * 60)
        let transition = FocusScheduleTransition(requestedEnabled: true, window: validWindow)

        XCTAssertFalse(transition.shouldStopMonitoring)
        XCTAssertTrue(transition.canStartMonitoring)
    }
}
