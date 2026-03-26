import SwiftUI
import MapKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updateManager: UpdateManager
    @State private var draftHomeName: String = ""
    @State private var draftHomeTimeZoneID: String = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section {
                headerView
            }

            Section("Smart Home") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $appState.autoDetectLocation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-detect Location")
                                .font(.body.weight(.medium))
                            Text("Use Location Services to update your home city automatically.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    if appState.autoDetectLocation {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(appState.accentColor)
                            Text("Currently at: **\(appState.homeName)**")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 2)
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Manual Home Location") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Search for your home city…", text: $draftHomeName)
                            .textFieldStyle(.roundedBorder)
                            .disabled(appState.autoDetectLocation)
                            .onChange(of: draftHomeName) { _, newValue in
                                if !appState.autoDetectLocation {
                                    appState.updateSearchQuery(newValue)
                                }
                            }
                        
                        // Autocomplete suggestions for Home City
                        if !appState.autoDetectLocation && !appState.searchSuggestions.isEmpty && !draftHomeName.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(appState.searchSuggestions.prefix(3), id: \.self) { suggestion in
                                    Button {
                                        selectHomeFromSuggestion(suggestion)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.subheadline)
                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(HoverBackground())
                                    
                                    Divider().padding(.horizontal, 10)
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .shadow(radius: 2)
                            .padding(.top, 4)
                        }
                    }

                    TextField("Time Zone ID (e.g. Europe/London)", text: $draftHomeTimeZoneID)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true) // Always derived from city search for best results
                        .overlay(alignment: .trailing) {
                            if appState.isSearching {
                                ProgressView().controlSize(.small).scaleEffect(0.6).padding(.trailing, 8)
                            }
                        }
                    
                    HStack {
                        Button("Apply Home Location") {
                            saveHomeLocation()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(appState.autoDetectLocation || draftHomeTimeZoneID.isEmpty)

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(validationMessage == "Saved." ? .green : .orange)
                                .padding(.leading, 8)
                        }
                    }
                    
                    if appState.autoDetectLocation {
                        Text("Manual override is disabled when auto-detection is active.")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $appState.isLaunchAtLoginEnabled)
            }

            Section("Appearance") {
                HStack {
                    Text("Accent Color")
                    Spacer()
                    
                    HStack(spacing: 8) {
                        ColorCircle(color: .accentColor, isSelected: appState.accentColorHex == "SYSTEM") {
                            appState.accentColorHex = "SYSTEM"
                        }
                        
                        ColorCircle(color: .orange, isSelected: appState.accentColorHex == "FFA500") {
                            appState.accentColorHex = "FFA500"
                        }
                        
                        ColorCircle(color: .purple, isSelected: appState.accentColorHex == "800080") {
                            appState.accentColorHex = "800080"
                        }
                        
                        ColorCircle(color: .green, isSelected: appState.accentColorHex == "008000") {
                            appState.accentColorHex = "008000"
                        }
                        
                        ColorCircle(color: .red, isSelected: appState.accentColorHex == "FF0000") {
                            appState.accentColorHex = "FF0000"
                        }
                    }
                }
            }

            Section("Menu Bar Display") {
                Picker("Show alternate time", selection: $appState.menuBarTimeZoneID) {
                    Text("Icon Only").tag(String?.none)
                    Divider()
                    ForEach(appState.savedLocations) { location in
                        Text(location.name).tag(Optional(location.timeZoneID))
                    }
                }
            }

            Section("Help & Examples") {
                Text("Common Time Zone IDs:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 6) {
                    exampleRow(city: "Israel", identifier: "Asia/Jerusalem")
                    exampleRow(city: "New York", identifier: "America/New_York")
                    exampleRow(city: "London", identifier: "Europe/London")
                    exampleRow(city: "Los Angeles", identifier: "America/Los_Angeles")
                    exampleRow(city: "Tokyo", identifier: "Asia/Tokyo")
                }
                .padding(.top, 4)
            }

            Section("Support") {
                Link(destination: URL(string: "https://buymeacoffee.com/eliko109")!) {
                    Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 550)
        .onAppear {
            draftHomeName = appState.homeName
            draftHomeTimeZoneID = appState.homeTimeZoneID
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Easy Time Zones")
                    .font(.title2.weight(.bold))
                Text("Configure your home base and display preferences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Text(updateManager.versionDisplay)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    if updateManager.isChecking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).scaleEffect(0.5)
                            Text("Checking...")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                updateManager.checkForUpdates()
                            } label: {
                                Text("Check for updates")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(appState.accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            if let error = updateManager.errorMessage {
                                Text(error)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red.opacity(0.8))
                            } else if updateManager.hasUpdate {
                                Text("New version available!")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                            } else if updateManager.lastCheckDate != nil {
                                Text("Up to date")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 12)
    }

    private func exampleRow(city: String, identifier: String) -> some View {
        HStack {
            Text(city)
                .font(.body.weight(.medium))
            Spacer()
            Text(identifier)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .help("Click to select and copy")
    }

    private func selectHomeFromSuggestion(_ suggestion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        
        Task { @MainActor in
            do {
                let response = try await search.start()
                if let item = response.mapItems.first, let location = item.placemark.location {
                    // Get actual TimeZone using geocoder
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let tz = placemarks.first?.timeZone {
                        self.draftHomeName = item.name ?? suggestion.title
                        self.draftHomeTimeZoneID = tz.identifier
                        self.appState.searchSuggestions = []
                    }
                }
            } catch {
                self.validationMessage = "Could not find time zone for this city."
            }
        }
    }

    private func saveHomeLocation() {
        let trimmedName = draftHomeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTimeZoneID = draftHomeTimeZoneID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Enter a home location name."
            return
        }

        guard TimeZone(identifier: trimmedTimeZoneID) != nil else {
            validationMessage = "Enter a valid macOS time zone ID."
            return
        }

        appState.homeName = trimmedName
        appState.homeTimeZoneID = trimmedTimeZoneID
        validationMessage = "Saved."
    }
}

struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .modifier(SelectionStroke(isSelected: isSelected))
            .onTapGesture(perform: action)
    }
}

struct SelectionStroke: ViewModifier {
    let isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected {
            content
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.4), lineWidth: 2)
                        .padding(-4)
                )
        } else {
            content
        }
    }
}
