import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit
import ServiceManagement

final class AppState: NSObject, ObservableObject {
    private enum DefaultsKey {
        static let homeName = "homeName"
        static let homeTimeZoneID = "homeTimeZoneID"
        static let use24HourFormat = "use24HourFormat"
        static let savedLocationsData = "savedLocationsData"
        static let accentColorHex = "accentColorHex"
        static let menuBarTimeZoneID = "menuBarTimeZoneID"
        static let autoDetectLocation = "autoDetectLocation"
    }

    private let defaults: UserDefaults
    private let locationManager = CLLocationManager()

    @Published var homeName: String {
        didSet { defaults.set(homeName, forKey: DefaultsKey.homeName) }
    }

    @Published var homeTimeZoneID: String {
        didSet { defaults.set(homeTimeZoneID, forKey: DefaultsKey.homeTimeZoneID) }
    }

    @Published var use24HourFormat: Bool {
        didSet { defaults.set(use24HourFormat, forKey: DefaultsKey.use24HourFormat) }
    }

    @Published var accentColorHex: String {
        didSet { defaults.set(accentColorHex, forKey: DefaultsKey.accentColorHex) }
    }

    @Published var menuBarTimeZoneID: String? {
        didSet { defaults.set(menuBarTimeZoneID, forKey: DefaultsKey.menuBarTimeZoneID) }
    }

    @Published var autoDetectLocation: Bool {
        didSet { 
            defaults.set(autoDetectLocation, forKey: DefaultsKey.autoDetectLocation)
            if autoDetectLocation { requestLocation() }
        }
    }

    @Published var searchSuggestions: [MKLocalSearchCompletion] = []
    private var searchCompleter = MKLocalSearchCompleter()
    
    @Published var selectedRemoteID: UUID?
    @Published var savedLocations: [SavedLocation] = []
    /// Number of 30-minute steps from "now". Range: -48...+48 (= ±24 hours).
    /// 0 means "live / now".
    @Published var timeOffsetSteps: Int = 0
    @Published var useHomeAsBase: Bool = true
    @Published var manualTimeInput: String = ""
    @Published var draftSearchText: String = ""
    @Published var addLocationError: String?
    @Published var isSearching: Bool = false
    @Published var isLaunchAtLoginEnabled: Bool = false {
        didSet {
            let service = SMAppService.mainApp
            if isLaunchAtLoginEnabled {
                if service.status != SMAppService.Status.enabled {
                    try? service.register()
                }
            } else {
                if service.status == SMAppService.Status.enabled {
                    try? service.unregister()
                }
            }
        }
    }
    
    private let geocoder = CLGeocoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.homeName = defaults.string(forKey: DefaultsKey.homeName) ?? "San Antonio, Texas"
        self.homeTimeZoneID = defaults.string(forKey: DefaultsKey.homeTimeZoneID) ?? "America/Chicago"
        
        // Sync launch at login status
        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == SMAppService.Status.enabled

        if defaults.object(forKey: DefaultsKey.use24HourFormat) == nil {
            self.use24HourFormat = true
        } else {
            self.use24HourFormat = defaults.bool(forKey: DefaultsKey.use24HourFormat)
        }

        self.accentColorHex = defaults.string(forKey: DefaultsKey.accentColorHex) ?? "SYSTEM"
        self.menuBarTimeZoneID = defaults.string(forKey: DefaultsKey.menuBarTimeZoneID)
        self.autoDetectLocation = defaults.bool(forKey: DefaultsKey.autoDetectLocation)

        super.init()

        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
        
        locationManager.delegate = self
        if autoDetectLocation {
            locationManager.startUpdatingLocation()
        }

        loadLocations()

        if savedLocations.isEmpty {
            savedLocations = [
                SavedLocation(name: "Israel", timeZoneID: "Asia/Jerusalem"),
                SavedLocation(name: "New York", timeZoneID: "America/New_York"),
                SavedLocation(name: "London", timeZoneID: "Europe/London")
            ]
            persistLocations()
        }

        selectedRemoteID = savedLocations.first?.id
    }

    var homeTimeZone: TimeZone {
        TimeZone(identifier: homeTimeZoneID) ?? .current
    }

    var accentColor: Color {
        accentColorHex == "SYSTEM" ? .accentColor : Color(hex: accentColorHex)
    }

    var selectedRemote: SavedLocation? {
        savedLocations.first(where: { $0.id == selectedRemoteID })
    }

    /// True minutes of offset from now.
    var timeOffsetMinutes: Int { timeOffsetSteps * 30 }

    /// The reference date used for all conversions.
    /// If offset is 0, it returns real now.
    /// If offset != 0, it rounds CURRENT time in the BASE timezone, then adds steps.
    var referenceDate: Date {
        let now = Date()
        guard !isLiveNow else { return now }

        let baseTZ = useHomeAsBase ? homeTimeZone : (selectedRemote?.timeZone ?? homeTimeZone)
        
        var calendar = Calendar.current
        calendar.timeZone = baseTZ
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = components.minute ?? 0
        
        // Nearest 30m mark for better 'snapping' experience
        let nearest30 = Int(round(Double(minute) / 30.0)) * 30
        
        if let startOfHour = calendar.date(bySettingHour: components.hour ?? 0, minute: 0, second: 0, of: now),
           let baseDate = calendar.date(byAdding: .minute, value: nearest30, to: startOfHour) {
            return baseDate.addingTimeInterval(TimeInterval(timeOffsetMinutes * 60))
        }
        
        return now.addingTimeInterval(TimeInterval(timeOffsetMinutes * 60))
    }

    func applyManualTime() {
        let input = manualTimeInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !input.isEmpty else { return }
        
        var hour: Int?
        var minute: Int?
        
        // 1. Check for HH:mm or H:m
        if input.contains(":") {
            let parts = input.components(separatedBy: ":")
            if parts.count >= 1 {
                hour = Int(parts[0].filter { $0.isNumber })
                if parts.count >= 2 {
                    let mStr = parts[1].filter { $0.isNumber }
                    if mStr.count == 1 {
                        // "10:5" -> 10:50 is often what people mean if typing fast, 
                        // but "10:05" is more common for apps. Let's guess based on value.
                        let mInt = Int(mStr) ?? 0
                        minute = mInt < 6 ? mInt * 10 : mInt 
                        // Actually, let's keep it simpler: "10:5" -> 10:05. 
                        // Most users type 10:30 for half past.
                        minute = mInt
                    } else if mStr.count == 2 {
                        minute = Int(mStr)
                    } else {
                        minute = 0
                    }
                } else {
                    minute = 0
                }
            }
        } 
        // 2. Pure numbers
        else {
            let digits = input.filter { $0.isNumber }
            if digits.count == 1 || digits.count == 2 {
                // "9" -> 09:00, "10" -> 10:00
                hour = Int(digits)
                minute = 0
            } else if digits.count == 3 {
                // "930" -> 09:30
                hour = Int(digits.prefix(1))
                minute = Int(digits.suffix(2))
            } else if digits.count == 4 {
                // "1030" -> 10:30
                hour = Int(digits.prefix(2))
                minute = Int(digits.suffix(2))
            }
        }
        
        // 3. Handle AM/PM
        let isPM = input.contains("pm")
        let isAM = input.contains("am")
        
        if let h = hour, let m = minute {
            var finalH = h
            if isPM && finalH < 12 { finalH += 12 }
            if isAM && finalH == 12 { finalH = 0 }
            
            if finalH >= 0 && finalH < 24 && m >= 0 && m < 60 {
                // Calculate steps from current 30-min base
                let calendar = Calendar.current
                let now = Date()
                
                var targetComponents = calendar.dateComponents(in: (useHomeAsBase ? homeTimeZone : (selectedRemote?.timeZone ?? homeTimeZone)), from: now)
                targetComponents.hour = finalH
                targetComponents.minute = m
                targetComponents.second = 0
                
                if let targetDate = calendar.date(from: targetComponents) {
                    // Calculate how many 30-min steps are needed to reach targetDate from 'now' (floor)
                    // Wait, referenceDate already includes offset.
                    // We need to calculate steps from the current time's base.
                    
                    let refTZ = useHomeAsBase ? homeTimeZone : (selectedRemote?.timeZone ?? homeTimeZone)
                    var cal = Calendar.current
                    cal.timeZone = refTZ
                    
                    let nowComp = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
                    let nowM = nowComp.minute ?? 0
                    let nearest30 = Int(round(Double(nowM) / 30.0)) * 30
                    let nowBase = cal.date(bySettingHour: nowComp.hour ?? 0, minute: 0, second: 0, of: now)!
                    let roundedNow = cal.date(byAdding: .minute, value: nearest30, to: nowBase)!
                    
                    let diffSeconds = targetDate.timeIntervalSince(roundedNow)
                    let steps = Int(round(diffSeconds / 1800.0)) // 1800s = 30m
                    
                    // Clamp to slider range
                    timeOffsetSteps = max(-48, min(48, steps))
                    
                    // Update input to canonical format so it "stays" as requested
                    self.manualTimeInput = String(format: "%02d:%02d", finalH, m)
                }
            }
        }
    }

    var isLiveNow: Bool { timeOffsetSteps == 0 }

    func loadLocations() {
        let savedLocationsData = defaults.data(forKey: DefaultsKey.savedLocationsData) ?? Data()

        guard !savedLocationsData.isEmpty else {
            savedLocations = []
            return
        }

        do {
            savedLocations = try JSONDecoder().decode([SavedLocation].self, from: savedLocationsData)
        } catch {
            print("Failed to decode locations: \(error)")
            savedLocations = []
        }
    }

    func persistLocations() {
        do {
            let savedLocationsData = try JSONEncoder().encode(savedLocations)
            defaults.set(savedLocationsData, forKey: DefaultsKey.savedLocationsData)
        } catch {
            print("Failed to encode locations: \(error)")
        }
    }

    func addLocationFromSearch() {
        let query = draftSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        addLocationError = nil

        Task { @MainActor in
            defer { self.isSearching = false }

            // 1. Try local quick match (IDs or common aliases)
            if let localTz = Self.matchingTimeZone(for: query) {
                self.addTimeZone(localTz, name: Self.prettyName(for: localTz.identifier, fallback: query))
                return
            }

            // 2. Try global geocoding (CLGeocoder)
            var foundTimeZone: TimeZone?
            var foundName: String?
            
            do {
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let first = placemarks.first, let tz = first.timeZone {
                    foundTimeZone = tz
                    foundName = first.locality ?? first.name
                }
            } catch {
                // Ignore CLGeocoder errors and proceed to MapKit fallback
            }

            if let tz = foundTimeZone, let name = foundName {
                self.addTimeZone(tz, name: name)
                return
            }

            // 3. Fallback to MapKit Search (much better for abbreviations, landmarks, and small towns)
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                if let firstItem = response.mapItems.first {
                    // Try to get TimeZone from the map item's location
                    if let location = firstItem.placemark.location {
                        let placemarks = try await geocoder.reverseGeocodeLocation(location)
                        if let tz = placemarks.first?.timeZone {
                            let name = firstItem.name ?? placemarks.first?.locality ?? query
                            self.addTimeZone(tz, name: name)
                            return
                        }
                    }
                }
            } catch {
                // Ignore MapKit errors too
            }

            self.addLocationError = "Could not find a time zone for “\(query)”. Try using the full city name."
        }
    }

    private func addTimeZone(_ timeZone: TimeZone, name: String) {
        if savedLocations.contains(where: { $0.timeZoneID == timeZone.identifier }) {
            addLocationError = "\(name) is already in your list."
            draftSearchText = ""
            return
        }

        let location = SavedLocation(
            name: name,
            timeZoneID: timeZone.identifier
        )

        savedLocations.append(location)
        persistLocations()
        selectedRemoteID = location.id
        draftSearchText = ""
        addLocationError = nil
    }

    func removeLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
        persistLocations()

        if selectedRemoteID == location.id {
            selectedRemoteID = savedLocations.first?.id
        }
    }

    static func matchingTimeZone(for query: String) -> TimeZone? {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // 1. Try built-in abbreviation (UTC, EST, PST, etc.)
        if let tz = TimeZone(abbreviation: normalizedQuery.uppercased()) {
            return tz
        }

        let aliases: [String: String] = [
            "san antonio": "America/Chicago",
            "texas": "America/Chicago",
            "israel": "Asia/Jerusalem",
            "jerusalem": "Asia/Jerusalem",
            "tel aviv": "Asia/Jerusalem",
            "tlv": "Asia/Jerusalem",
            "utc": "UTC",
            "gmt": "GMT",
            "est": "America/New_York",
            "cst": "America/Chicago",
            "pst": "America/Los_Angeles",
            "la": "America/Los_Angeles",
            "new york": "America/New_York",
            "nyc": "America/New_York",
            "london": "Europe/London",
            "paris": "Europe/Paris",
            "berlin": "Europe/Berlin",
            "tokyo": "Asia/Tokyo",
            "bangkok": "Asia/Bangkok",
            "bkk": "Asia/Bangkok",
            "koh phangan": "Asia/Bangkok",
            "phuket": "Asia/Bangkok",
            "dubai": "Asia/Dubai",
            "dxb": "Asia/Dubai",
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

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func addLocation(from completion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        isSearching = true
        Task { @MainActor in
            defer { self.isSearching = false }
            do {
                let response = try await search.start()
                if let item = response.mapItems.first, let location = item.placemark.location {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let tz = placemarks.first?.timeZone {
                        let name = item.name ?? placemarks.first?.locality ?? completion.title
                        self.addTimeZone(tz, name: name)
                        self.draftSearchText = ""
                        self.searchSuggestions = []
                    }
                }
            } catch {
                self.addLocationError = "Could not find time zone for this location."
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension AppState: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let tz = placemarks?.first?.timeZone else { return }
            DispatchQueue.main.async {
                if self.homeTimeZoneID != tz.identifier {
                    self.homeTimeZoneID = tz.identifier
                    self.homeName = placemarks?.first?.locality ?? self.homeName
                }
            }
        }
        manager.stopUpdatingLocation()
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension AppState: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchSuggestions = completer.results
    }
    
    func updateSearchQuery(_ query: String) {
        searchCompleter.queryFragment = query
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
