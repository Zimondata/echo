import XCTest
@testable import Echo

@MainActor
final class AppModelScheduleTests: XCTestCase {
    func testDisableStopsAndPersistsEvenAfterInvalidTimeEdit() {
        var events: [String] = []
        let model = AppModel(scheduleSideEffects: ScheduleSideEffects(
            startMonitoring: { _ in events.append("start") },
            stopMonitoring: { events.append("stop") },
            persistEnabled: { events.append("persist:\($0)") },
            clearShields: { events.append("clear") }
        ))
        model.scheduleEnabled = true
        model.focusEnabled = false
        model.scheduleStart = Date(timeIntervalSince1970: 36_000)
        model.scheduleEnd = model.scheduleStart

        model.setSchedule(enabled: false)

        XCTAssertFalse(model.scheduleEnabled)
        XCTAssertEqual(events, ["stop", "clear", "persist:false"])
        XCTAssertEqual(model.message, "Расписание выключено")
    }

    func testDisablePreservesManualFocusShield() {
        var events: [String] = []
        let model = AppModel(scheduleSideEffects: ScheduleSideEffects(
            startMonitoring: { _ in events.append("start") },
            stopMonitoring: { events.append("stop") },
            persistEnabled: { events.append("persist:\($0)") },
            clearShields: { events.append("clear") }
        ))
        model.scheduleEnabled = true
        model.focusEnabled = true
        model.scheduleStart = Date(timeIntervalSince1970: 36_000)
        model.scheduleEnd = model.scheduleStart

        model.setSchedule(enabled: false)

        XCTAssertEqual(events, ["stop", "persist:false"])
        XCTAssertTrue(model.focusEnabled)
    }

    func testInvalidEnableStopsOldMonitorAndPersistsDisabled() {
        var events: [String] = []
        let model = AppModel(scheduleSideEffects: ScheduleSideEffects(
            startMonitoring: { _ in events.append("start") },
            stopMonitoring: { events.append("stop") },
            persistEnabled: { events.append("persist:\($0)") },
            clearShields: { events.append("clear") }
        ))
        model.scheduleEnabled = true
        model.focusEnabled = false
        model.scheduleStart = Date(timeIntervalSince1970: 36_000)
        model.scheduleEnd = model.scheduleStart

        model.setSchedule(enabled: true)

        XCTAssertFalse(model.scheduleEnabled)
        XCTAssertEqual(events, ["stop", "clear", "persist:false"])
        XCTAssertEqual(model.message, "Начало и конец расписания должны отличаться")
    }
}
