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
                .task {
                    // Check for updates 2 seconds after the menu appears
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    updateManager.checkForUpdates()
                }

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
