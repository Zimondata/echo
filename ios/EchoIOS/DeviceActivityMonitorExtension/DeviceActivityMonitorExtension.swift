import DeviceActivity
import EchoScreenTime
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .echoFocus else { return }
        guard let selection = (try? FamilySelectionStore())?.load() else {
            ShieldController.clear()
            return
        }
        ShieldController.apply(selection)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .echoFocus else { return }

        let manualFocusIsEnabled = UserDefaults(suiteName: EchoAppGroup.identifier)?
            .bool(forKey: EchoAppGroup.focusEnabledKey) ?? false
        if manualFocusIsEnabled, let selection = (try? FamilySelectionStore())?.load() {
            ShieldController.apply(selection)
        } else {
            ShieldController.clear()
        }
    }
}
