import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draftHomeName: String = ""
    @State private var draftHomeTimeZoneID: String = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section("Home Location") {
                TextField("Display name", text: $draftHomeName)
                TextField("Time zone ID", text: $draftHomeTimeZoneID)

                HStack {
                    Button("Save") {
                        saveHomeLocation()
                    }
                    .buttonStyle(.borderedProminent)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Default: San Antonio, Texas / America/Chicago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Format") {
                Toggle("Use 24-Hour Format", isOn: $appState.use24HourFormat)
                    .tint(Brand.primary)
            }

            Section("Common Time Zone IDs") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Israel: Asia/Jerusalem")
                    Text("New York: America/New_York")
                    Text("London: Europe/London")
                    Text("Los Angeles: America/Los_Angeles")
                    Text("Tokyo: Asia/Tokyo")
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            draftHomeName = appState.homeName
            draftHomeTimeZoneID = appState.homeTimeZoneID
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
