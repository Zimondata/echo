import EchoCore
import EchoScreenTime
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let snapshot = (try? SharedPlanSnapshotStore())?.load() ?? PlanSnapshot(
            generatedAt: .now,
            timezoneIdentifier: TimeZone.current.identifier,
            items: [],
            source: .preview
        )
        let copy = InterventionPolicy.copy(for: snapshot)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.035, green: 0.035, blue: 0.059, alpha: 1),
            icon: UIImage(systemName: "wave.3.right.circle.fill"),
            title: ShieldConfiguration.Label(text: copy.title, color: .white),
            subtitle: ShieldConfiguration.Label(text: copy.subtitle, color: UIColor(white: 0.83, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: copy.primaryAction, color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: copy.secondaryAction, color: UIColor(white: 0.78, alpha: 1))
        )
    }
}
