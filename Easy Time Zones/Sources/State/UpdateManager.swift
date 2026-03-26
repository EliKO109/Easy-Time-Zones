import Foundation
import Combine

/// Checks GitHub for a newer release and publishes `hasUpdate`.
final class UpdateManager: ObservableObject {

    // MARK: – Config
    private static let repoAPI = "https://api.github.com/repos/EliKO109/Easy-Time-Zones/releases/latest"
    static let releasesPage = "https://github.com/EliKO109/Easy-Time-Zones/releases/latest"

    // MARK: – State
    @Published private(set) var hasUpdate = false
    @Published private(set) var latestVersion: String = ""
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckDate: Date? = nil
    @Published private(set) var errorMessage: String? = nil

    /// Current bundle display version (e.g. "1.1.0")
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Current bundle build number (e.g. "3")
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var versionDisplay: String {
        "Version \(currentVersion) (Build \(currentBuild))"
    }

    // MARK: – Public API
    func checkForUpdates() {
        Task {
            await MainActor.run { isChecking = true }
            await fetch()
            await MainActor.run { 
                isChecking = false
                lastCheckDate = Date()
            }
        }
    }

    // MARK: – Private
    private func fetch() async {
        guard let url = URL(string: Self.repoAPI) else { return }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("EasyTimeZones-App", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                let msg = "GitHub API Error \(httpResp.statusCode)"
                print(msg)
                await MainActor.run { errorMessage = msg }
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                let remote = normalised(tag)
                let local  = normalised(currentVersion)
                let newer  = isNewer(remote, than: local)
                // Update @Published properties on the main thread
                await MainActor.run {
                    latestVersion = remote
                    hasUpdate = newer
                    errorMessage = nil
                }
            } else {
                await MainActor.run { errorMessage = "Invalid JSON response" }
            }
        } catch {
            let msg = "Network Error: \(error.localizedDescription)"
            await MainActor.run { errorMessage = msg }
        }
    }

    /// Strips a leading "v" so "v1.2.0" == "1.2.0"
    private func normalised(_ v: String) -> String { v.hasPrefix("v") ? String(v.dropFirst()) : v }

    /// Semantic version comparison (major.minor.patch)
    private func isNewer(_ remote: String, than local: String) -> Bool {
        let parse: (String) -> [Int] = { $0.split(separator: ".").compactMap { Int($0) } }
        let r = parse(remote), l = parse(local)
        for i in 0 ..< max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }
}
