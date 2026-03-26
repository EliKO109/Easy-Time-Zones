import SwiftUI

@main
struct EasyTimeZonesApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var updateManager = UpdateManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .environmentObject(updateManager)
                .fixedSize(horizontal: true, vertical: true)

        } label: {
            MenuBarLabelView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(updateManager)
                .frame(width: 440)
                .padding()
        }
    }
}
