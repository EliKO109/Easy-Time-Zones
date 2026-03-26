import Foundation

/// Checks GitHub for a newer release and publishes `hasUpdate`.
@MainActor
final class UpdateManager: ObservableObject {

    // MARK: – Config
    private static let repoAPI = "https://api.github.com/repos/EliKO109/Easy-Time-Zones/releases/latest"
    static let releasesPage = "https://github.com/EliKO109/Easy-Time-Zones/releases/latest"

    // MARK: – State
    @Published private(set) var hasUpdate = false
    @Published private(set) var latestVersion: String = ""

    /// Current bundle short version (e.g. "1.0.0")
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: – Public API
    func checkForUpdates() {
        Task {
            await fetch()
        }
    }

    // MARK: – Private
    private func fetch() async {
        guard let url = URL(string: Self.repoAPI) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                let remote = normalised(tag)       // e.g. "1.2.0"
                let local  = normalised(currentVersion)
                latestVersion = remote
                hasUpdate = isNewer(remote, than: local)
            }
        } catch {
            // Silently fail – network or parse error shouldn't crash the app.
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
