import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

@main
struct EasyTimeZonesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .frame(width: 380)
                .padding(14)
        } label: {
            MenuBarLabelView()
                .environmentObject(appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 440)
                .padding()
        }
    }
}
