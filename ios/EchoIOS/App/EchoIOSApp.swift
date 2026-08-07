import SwiftUI

@main
struct EchoIOSApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Color.echoViolet)
        }
    }
}

extension Color {
    static let echoCanvas = Color(red: 0.035, green: 0.035, blue: 0.059)
    static let echoSurface = Color(red: 0.075, green: 0.063, blue: 0.12)
    static let echoViolet = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let echoLavender = Color(red: 0.82, green: 0.73, blue: 1.0)
}
