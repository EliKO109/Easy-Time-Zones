import Foundation
import Combine
import Sparkle

@MainActor
final class UpdateManager: ObservableObject {
    private let updaterController: SPUStandardUpdaterController?

    init() {
        if Self.isSparkleConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var versionDisplay: String {
        "Version \(currentVersion) (Build \(currentBuild))"
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    func checkForUpdates() {
        guard let updaterController else { return }
        updaterController.checkForUpdates(nil)
    }

    private static var isSparkleConfigured: Bool {
        let infoDictionary = Bundle.main.infoDictionary ?? [:]
        let feedURL = infoDictionary["SUFeedURL"] as? String
        let publicKey = infoDictionary["SUPublicEDKey"] as? String

        return !(feedURL?.isEmpty ?? true) && !(publicKey?.isEmpty ?? true)
    }
}
