import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { PlanView() }
                .tabItem { Label("План", systemImage: "calendar") }

            NavigationStack { FocusView() }
                .tabItem { Label("Фокус", systemImage: "shield.lefthalf.filled") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .background(Color.echoCanvas.ignoresSafeArea())
    }
}
