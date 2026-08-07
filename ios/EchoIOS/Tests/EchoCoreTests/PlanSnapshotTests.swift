import Foundation
import XCTest
@testable import EchoCore

final class PlanSnapshotTests: XCTestCase {
    func testSelectsActiveItemBeforeNextItem() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = PlanSnapshot(
            generatedAt: now,
            timezoneIdentifier: "Europe/Madrid",
            items: [
                PlanItem(id: "later", title: "Записать видео", startsAt: now.addingTimeInterval(3_600), endsAt: now.addingTimeInterval(5_400), kind: .task),
                PlanItem(id: "active", title: "Собрать Echo", startsAt: now.addingTimeInterval(-600), endsAt: now.addingTimeInterval(600), kind: .timeBlock)
            ]
        )

        XCTAssertEqual(snapshot.focusItem(at: now, calendar: calendar)?.id, "active")
        XCTAssertEqual(snapshot.focusItem(at: now.addingTimeInterval(1_200), calendar: calendar)?.id, "later")
    }

    func testFiltersPlanItemsToRequestedLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 9))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let snapshot = PlanSnapshot(
            generatedAt: day,
            timezoneIdentifier: "Europe/Madrid",
            items: [
                PlanItem(id: "today", title: "Главный шаг", startsAt: day, endsAt: day.addingTimeInterval(3_600), kind: .task),
                PlanItem(id: "tomorrow", title: "Потом", startsAt: tomorrow, endsAt: tomorrow.addingTimeInterval(3_600), kind: .task)
            ]
        )

        XCTAssertEqual(snapshot.items(on: day, calendar: calendar).map(\.id), ["today"])
    }

    func testFixtureIsAnHonestLocalPreview() {
        let snapshot = PlanSnapshot.preview(referenceDate: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(snapshot.source, .preview)
        XCTAssertFalse(snapshot.items.isEmpty)
    }
}
