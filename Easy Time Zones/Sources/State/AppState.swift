import SwiftUI
import Foundation
import Combine

final class AppState: ObservableObject {
    @AppStorage("homeName") var homeName: String = "San Antonio, Texas"
    @AppStorage("homeTimeZoneID") var homeTimeZoneID: String = "America/Chicago"
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = true
    @AppStorage("savedLocationsData") private var savedLocationsData: Data = Data()

    @Published var selectedRemoteID: UUID?
    @Published var inputHour: Int = 8
    @Published var inputMinute: Int = 0
    @Published var inputDayOffset: Int = 0
    @Published var useNowAsInput: Bool = true
    @Published var draftSearchText: String = ""
    @Published var addLocationError: String?
    @Published var savedLocations: [SavedLocation] = [] {
        didSet { persistLocations() }
    }

    init() {
        loadLocations()

        if savedLocations.isEmpty {
            savedLocations = [
                SavedLocation(name: "Israel", timeZoneID: "Asia/Jerusalem"),
                SavedLocation(name: "New York", timeZoneID: "America/New_York"),
                SavedLocation(name: "London", timeZoneID: "Europe/London")
            ]
        }

        selectedRemoteID = savedLocations.first?.id
    }

    var homeTimeZone: TimeZone {
        TimeZone(identifier: homeTimeZoneID) ?? .current
    }

    var selectedRemote: SavedLocation? {
        savedLocations.first(where: { $0.id == selectedRemoteID })
    }

    func loadLocations() {
        guard !savedLocationsData.isEmpty else {
            savedLocations = []
            return
        }

        do {
            savedLocations = try JSONDecoder().decode([SavedLocation].self, from: savedLocationsData)
        } catch {
            savedLocations = []
        }
    }

    func persistLocations() {
        do {
            savedLocationsData = try JSONEncoder().encode(savedLocations)
        } catch {
            print("Failed to save locations: \(error)")
        }
    }

    func addLocationFromSearch() {
        let query = draftSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        guard let timeZone = Self.matchingTimeZone(for: query) else {
            addLocationError = "No time zone found for “\(query)”. Try a city, country, or full time zone ID."
            return
        }

        if savedLocations.contains(where: { $0.timeZoneID == timeZone.identifier }) {
            addLocationError = "\(Self.prettyName(for: timeZone.identifier)) is already in your list."
            draftSearchText = ""
            return
        }

        let location = SavedLocation(
            name: Self.prettyName(for: timeZone.identifier, fallback: query),
            timeZoneID: timeZone.identifier
        )

        savedLocations.append(location)
        selectedRemoteID = location.id
        draftSearchText = ""
        addLocationError = nil
    }

    func removeLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }

        if selectedRemoteID == location.id {
            selectedRemoteID = savedLocations.first?.id
        }
    }

    static func matchingTimeZone(for query: String) -> TimeZone? {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let aliases: [String: String] = [
            "san antonio": "America/Chicago",
            "texas": "America/Chicago",
            "israel": "Asia/Jerusalem",
            "jerusalem": "Asia/Jerusalem",
            "tel aviv": "Asia/Jerusalem",
            "new york": "America/New_York",
            "nyc": "America/New_York",
            "london": "Europe/London",
            "los angeles": "America/Los_Angeles",
            "california": "America/Los_Angeles",
            "paris": "Europe/Paris",
            "berlin": "Europe/Berlin",
            "tokyo": "Asia/Tokyo",
            "bangkok": "Asia/Bangkok",
            "sydney": "Australia/Sydney"
        ]

        if let aliasID = aliases[normalizedQuery] {
            return TimeZone(identifier: aliasID)
        }

        if let exactMatch = TimeZone.knownTimeZoneIdentifiers.first(where: { $0.lowercased() == normalizedQuery }) {
            return TimeZone(identifier: exactMatch)
        }

        if let cityMatch = TimeZone.knownTimeZoneIdentifiers.first(where: {
            $0.lowercased().replacingOccurrences(of: "_", with: " ").contains(normalizedQuery)
        }) {
            return TimeZone(identifier: cityMatch)
        }

        return nil
    }

    static func prettyName(for timeZoneID: String, fallback: String? = nil) -> String {
        let cleaned = timeZoneID
            .split(separator: "/")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ")

        return cleaned ?? fallback ?? timeZoneID
    }
}
