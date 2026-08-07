import DeviceActivity
import EchoCore
import EchoScreenTime
import Foundation

struct ScheduleSideEffects {
    var startMonitoring: (DeviceActivitySchedule) throws -> Void
    var stopMonitoring: () -> Void
    var persistEnabled: (Bool) throws -> Void
    var clearShields: () -> Void

    static let live = ScheduleSideEffects(
        startMonitoring: { schedule in
            try DeviceActivityCenter().startMonitoring(.echoFocus, during: schedule)
        },
        stopMonitoring: {
            DeviceActivityCenter().stopMonitoring([.echoFocus])
        },
        persistEnabled: { enabled in
            guard let defaults = UserDefaults(suiteName: EchoAppGroup.identifier) else {
                throw EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier)
            }
            defaults.set(enabled, forKey: EchoAppGroup.scheduleEnabledKey)
        },
        clearShields: {
            ShieldController.clear()
        }
    )
}
