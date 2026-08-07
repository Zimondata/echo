import DeviceActivity
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .echoFocus,
              let selection = FamilySelectionStore()?.load()
        else { return }
        ShieldController.apply(selection)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .echoFocus else { return }

        let manualFocusIsEnabled = UserDefaults(suiteName: EchoAppGroup.identifier)?
            .bool(forKey: EchoAppGroup.focusEnabledKey) ?? false
        if manualFocusIsEnabled, let selection = FamilySelectionStore()?.load() {
            ShieldController.apply(selection)
        } else {
            ShieldController.clear()
        }
    }
}
