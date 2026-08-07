# Echo iOS

Native SwiftUI companion for Echo. The project lives inside the existing Echo repository but is isolated under `ios/EchoIOS`.

## What is implemented

- Native SwiftUI Plan screen with Today and Month modes.
- Explicit plan timezone rendering (`Europe/Madrid` in the local preview).
- Family Controls authorization for an individual device owner.
- Apple's privacy-preserving `FamilyActivityPicker` for selecting Instagram, other apps, categories, and domains.
- Immediate blocking through `ManagedSettingsStore`.
- Daily recurring focus schedules through `DeviceActivityCenter` and a Device Activity Monitor extension.
- Custom system shield UI that shows the current or next Echo plan item before a selected app opens.
- Shield actions: return/close the blocked app, or deliberately defer the decision.
- Shared App Group storage for opaque selection tokens and a bounded plan snapshot.
- Local preview plan only; production sync is intentionally not faked and does not bypass Echo's Telegram authentication.
- Pure Swift domain verification plus Xcode unit tests.

## Project layout

- `EchoIOS.xcodeproj` — generated Xcode project; open this in Xcode.
- `project.yml` — XcodeGen source of truth.
- `App/` — SwiftUI application.
- `Shared/EchoCore/` — portable plan and intervention logic.
- `Shared/EchoScreenTime/` — App Group, selection, shielding, and scheduling support.
- `ShieldConfigurationExtension/` — content shown over blocked apps.
- `ShieldActionExtension/` — system shield button handling.
- `DeviceActivityMonitorExtension/` — recurring schedule boundaries.
- `Tests/EchoCoreTests/` — Xcode unit tests.
- `Verification/` — CLI verification runnable without the iPhone SDK.

## Verified on this Mac

```bash
cd /Users/pine/Development/echo/ios/EchoIOS
xcodegen generate
swift run EchoCoreVerification
```

Expected result:

```text
EchoCoreVerification: PASS (14 checks)
```

Also verified:

- all Swift files parse with the installed Swift 6.2.4 compiler;
- all entitlements and generated plist/project files pass `plutil`;
- XcodeGen produces seven targets: app, two static libraries, three Screen Time extensions, and the unit-test bundle;
- the actual `PlanView` compiles and renders through macOS SwiftUI at `390×844`; visual review passed with no overflow or clipping.

## First Xcode run

The Mac currently has only Command Line Tools. Full Xcode and the iPhone SDK are not installed.

Once Xcode is available:

1. Open `/Users/pine/Development/echo/ios/EchoIOS/EchoIOS.xcodeproj`.
2. Select the `Echo` scheme.
3. In Signing & Capabilities, choose Zhenya's Apple development Team for the app and all three extensions.
4. Keep the Family Controls capability on the app and every Screen Time extension.
5. Keep App Group `group.space.datapine.echo` on the app, Shield Configuration, and Device Activity Monitor targets. If the identifier is already owned by another team, replace it consistently in `project.yml`, all entitlements, and `EchoAppGroup.swift`, then regenerate.
6. Connect a physical iPhone, enable Developer Mode if iOS asks, and choose it as the run destination.
7. Run the app, tap **Разрешить**, choose Instagram in Apple's picker, then enable **Блокировать прямо сейчас**.
8. Open Instagram. iOS should display the Echo shield with the current or next plan item.

Screen Time behavior must be proven on a physical device. Simulator-only evidence is not sufficient.

## Current hard blockers

- Only about 23 GiB is free on the Mac. A full Xcode installation normally needs substantially more working space during download and expansion. No user files or caches were deleted automatically.
- The unattended App Store install was attempted through `mas` but stopped at the macOS administrator-password prompt. Zhenya must approve/install Xcode interactively; Gary does not enter passwords.
- A development Team/signing identity must be selected in Xcode. Local device installation cannot be completed without the user's Apple account/team and iPhone trust/Developer Mode prompts.
- Distribution through TestFlight/App Store requires Apple approval for the Family Controls entitlement for the host app and each Screen Time extension.
- Production Echo does not yet expose a secure native-client auth/token flow. The current build labels its data as local preview instead of pretending to sync.

## Regenerating the project

Edit `project.yml`, then run:

```bash
xcodegen generate
```

Do not hand-edit `project.pbxproj`; generated changes will be overwritten.
