import Foundation
import EchoCore

struct VerificationFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw VerificationFailure(description: message) }
}

let now = Date(timeIntervalSince1970: 1_800_000_000)
let active = PlanItem(id: "active", title: "Собрать Echo", startsAt: now.addingTimeInterval(-600), endsAt: now.addingTimeInterval(600), kind: .timeBlock)
let later = PlanItem(id: "later", title: "Записать видео", startsAt: now.addingTimeInterval(3_600), endsAt: now.addingTimeInterval(5_400), kind: .task)
let snapshot = PlanSnapshot(generatedAt: now, timezoneIdentifier: "Europe/Madrid", items: [later, active])

try expect(snapshot.focusItem(at: now)?.id == "active", "active plan item must win")
try expect(snapshot.focusItem(at: now.addingTimeInterval(1_200))?.id == "later", "next plan item must follow")

let copy = InterventionPolicy.copy(for: snapshot, now: now)
try expect(copy.title == "Сейчас по плану", "shield title must explain the interruption")
try expect(copy.subtitle.contains("Собрать Echo"), "shield must expose the current plan")
try expect(copy.subtitle.count <= 120, "shield subtitle must remain bounded")

let empty = PlanSnapshot(generatedAt: now, timezoneIdentifier: "Europe/Madrid", items: [])
try expect(InterventionPolicy.copy(for: empty, now: now).title == "Ты точно сюда хотел?", "empty plan fallback must remain useful")
try expect(PlanSnapshot.preview(referenceDate: now).source == .preview, "fixture provenance must be explicit")

let overnight = DailyFocusWindow(startMinute: 22 * 60, endMinute: 7 * 60)
try expect(overnight.contains(minuteOfDay: 23 * 60), "overnight focus must include late evening")
try expect(overnight.contains(minuteOfDay: 8 * 60) == false, "overnight focus must end in the morning")
try expect(DailyFocusWindow(startMinute: 10 * 60, endMinute: 12 * 60).isValid, "ordinary focus interval must be valid")
try expect(DailyFocusWindow(startMinute: 10 * 60, endMinute: 10 * 60).isValid == false, "zero-length interval must be rejected")

print("EchoCoreVerification: PASS (10 checks)")
