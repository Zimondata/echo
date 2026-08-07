# Screen Time implementation evidence

Checked against Apple's current documentation on 2026-08-07.

## Direct evidence

1. [Family Controls](https://developer.apple.com/documentation/familycontrols) authorizes apps to provide controls on a device.
2. [`FamilyControlsMember.individual`](https://developer.apple.com/documentation/familycontrols/familycontrolsmember/individual) supports a person authorizing controls for their own account on iOS 16+.
3. [`FamilyActivityPicker`](https://developer.apple.com/documentation/familycontrols/familyactivitypicker) lets the user select applications, domains, and categories without revealing those choices to the app. Echo stores only Apple's opaque tokens.
4. [Managed Settings](https://developer.apple.com/documentation/managedsettings) changes shield settings while maintaining user privacy and control.
5. [`ShieldConfiguration`](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration) defines the system shield displayed over an application or website. Its customization surface is icon, title, subtitle, and primary/secondary labels — not an arbitrary SwiftUI month screen.
6. [`ShieldActionResponse.close`](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/close) tells iOS to close the current app/browser. Echo uses it for “Вернуться к плану”.
7. [`ShieldActionResponse.defer`](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/defer) defers a response. Echo uses it for the deliberate secondary path on iOS 17+.
8. [`ShieldActionResponse.openParentalControlsApp`](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp) can open the host parental-controls app, but Apple marks it iOS/iPadOS 26.5+. The current broad iOS 17 target does not depend on it. Once the installed SDK and iPhone both support 26.5, the secondary button can conditionally open full Echo.
9. [`DeviceActivitySchedule`](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule) provides calendar-based device-activity scheduling. Echo uses a recurring daily interval.
10. [`DeviceActivityMonitor`](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor) receives schedule interval boundaries in an extension. Echo applies shields at start and removes them at end unless manual focus remains active.
11. [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement): before distribution, the Apple Developer Account Holder must request the entitlement. Apple explicitly requires the same request for Screen Time extensions; with automatic signing, an existing development capability is updated after approval.

## Honest UX boundary

Apple does not allow Echo to draw any arbitrary screen over Instagram. The supported intervention is Apple's system shield with bounded Echo content. Therefore the first implementation shows:

- title: “Сейчас по плану” or “Следующее по плану”;
- subtitle: time plus the current/next plan item, bounded to 120 characters;
- primary action: close Instagram and return;
- secondary action: deliberate defer on iOS 17–26.4; a future conditional host-app launch on iOS 26.5+.

The complete Day/Month plan remains inside the Echo app. This is the strongest technically honest Apple-supported version of “show my plan when I open Instagram.”
