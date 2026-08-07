import Foundation
import XCTest
@testable import EchoCore

final class InterventionPolicyTests: XCTestCase {
    func testShowsCurrentPlanItemWhenBlockedAppIsOpened() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = PlanSnapshot(
            generatedAt: now,
            timezoneIdentifier: "Europe/Madrid",
            items: [
                PlanItem(id: "focus", title: "Допилить iOS-приложение", startsAt: now.addingTimeInterval(-300), endsAt: now.addingTimeInterval(2_700), kind: .timeBlock)
            ]
        )

        let copy = InterventionPolicy.copy(for: snapshot, now: now)

        XCTAssertEqual(copy.title, "Сейчас по плану")
        XCTAssertTrue(copy.subtitle.contains("Допилить iOS-приложение"))
        XCTAssertEqual(copy.primaryAction, "Вернуться к плану")
    }

    func testFallsBackToDeliberatePauseWhenPlanIsEmpty() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = PlanSnapshot(generatedAt: now, timezoneIdentifier: "Europe/Madrid", items: [])

        let copy = InterventionPolicy.copy(for: snapshot, now: now)

        XCTAssertEqual(copy.title, "Ты точно сюда хотел?")
        XCTAssertFalse(copy.subtitle.isEmpty)
    }

    func testShieldTextStaysWithinSystemUILimits() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = PlanSnapshot(
            generatedAt: now,
            timezoneIdentifier: "Europe/Madrid",
            items: [PlanItem(id: "long", title: String(repeating: "Очень длинная задача ", count: 20), startsAt: now, endsAt: nil, kind: .task)]
        )

        let copy = InterventionPolicy.copy(for: snapshot, now: now)

        XCTAssertLessThanOrEqual(copy.subtitle.count, 120)
    }
}
