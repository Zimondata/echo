import Foundation

public enum EchoSharedStoreError: LocalizedError, Sendable {
    case appGroupUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "App Group \(identifier) недоступен. Проверь capability и signing."
        }
    }
}

public enum EchoAppGroup {
    public static let identifier = "group.space.datapine.echo"
    public static let planSnapshotKey = "echo.plan.snapshot.v1"
    public static let familySelectionKey = "echo.family.selection.v1"
    public static let focusEnabledKey = "echo.focus.enabled.v1"
    public static let scheduleEnabledKey = "echo.focus.schedule.enabled.v1"
    public static let scheduleStartMinuteKey = "echo.focus.schedule.start-minute.v1"
    public static let scheduleEndMinuteKey = "echo.focus.schedule.end-minute.v1"
}
