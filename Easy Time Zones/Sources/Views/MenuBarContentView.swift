import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 20) {
                headerSection(now: timeline.date)
                
                VStack(alignment: .leading, spacing: 20) {
                    locationsSection(now: timeline.date)
                    Divider()
                        .opacity(0.3)
                    conversionSection(now: timeline.date)
                    Divider()
                        .opacity(0.3)
                    footerActions
                }
                .padding(16)
                .background(Color.black.opacity(0.2))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .padding(14)
            .background(.ultraThinMaterial)
        }
    }

    private func headerSection(now: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EASY TIME ZONES")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.primary)
                    .tracking(1.5)

                Text(appState.homeName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Home Location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(TimeFormatter.shortTimeString(from: now, timeZone: appState.homeTimeZone, is24Hour: appState.use24HourFormat))
                .font(.system(size: 28, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Brand.primary.opacity(0.1))
                .cornerRadius(10)
        }
        .padding(.horizontal, 4)
    }

    private func locationsSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare With")
                .font(.subheadline.weight(.semibold))

            Picker("Location", selection: selectedLocationBinding) {
                ForEach(appState.savedLocations) { location in
                    Text("\(location.name) • \(TimeFormatter.shortTimeString(from: now, timeZone: location.timeZone, is24Hour: appState.use24HourFormat))")
                        .tag(location.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(appState.savedLocations.isEmpty)

            HStack(spacing: 8) {
                TextField("Search city...", text: $appState.draftSearchText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .onSubmit {
                        appState.addLocationFromSearch()
                    }

                Button(action: appState.addLocationFromSearch) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Brand.primary)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if let addLocationError = appState.addLocationError {
                Text(addLocationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if appState.savedLocations.isEmpty {
                Text("No saved comparison locations yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.savedLocations) { location in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                    Text(location.timeZoneID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(TimeFormatter.shortTimeString(from: now, timeZone: location.timeZone, is24Hour: appState.use24HourFormat))
                                    .font(.system(.body, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.secondary)

                                Button {
                                    appState.removeLocation(location)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .help("Remove \(location.name)")
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 138)
            }
        }
    }

    private func conversionSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Convert Time")
                .font(.subheadline.weight(.semibold))

            Toggle("Use current time in selected location", isOn: $appState.useNowAsInput)

            if !appState.useNowAsInput {
                HStack(spacing: 8) {
                    Picker("Hour", selection: $appState.inputHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .frame(width: 82)

                    Picker("Minute", selection: $appState.inputMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .frame(width: 82)

                    Picker("Day", selection: $appState.inputDayOffset) {
                        Text("Yesterday").tag(-1)
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                    }
                    .frame(width: 120)
                }
            }

            if let remoteLocation = appState.selectedRemote {
                let referenceDate = conversionReferenceDate(now: now, remoteTimeZone: remoteLocation.timeZone)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected location")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        let remoteTime = TimeFormatter.fullDateTimeString(from: referenceDate, timeZone: remoteLocation.timeZone, is24Hour: appState.use24HourFormat)
                        let homeTime = TimeFormatter.fullDateTimeString(from: referenceDate, timeZone: appState.homeTimeZone, is24Hour: appState.use24HourFormat)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(remoteLocation.name): \(remoteTime)")
                                .font(.subheadline)
                            Text("At home: \(homeTime)")
                                .font(.headline)
                                .foregroundStyle(Brand.primary)
                        }
                        
                        Spacer()
                        
                        Button {
                            TimeFormatter.copyToClipboard("\(remoteLocation.name): \(remoteTime)\nHome: \(homeTime)")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Add a location to start converting between time zones.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footerActions: some View {
        HStack {
            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
    }

    private var selectedLocationBinding: Binding<UUID> {
        Binding(
            get: { appState.selectedRemoteID ?? appState.savedLocations.first?.id ?? UUID() },
            set: { appState.selectedRemoteID = $0 }
        )
    }

    private func conversionReferenceDate(now: Date, remoteTimeZone: TimeZone) -> Date {
        guard !appState.useNowAsInput else {
            return now
        }

        var remoteCalendar = Calendar(identifier: .gregorian)
        remoteCalendar.timeZone = remoteTimeZone

        let remoteNow = now
        var components = remoteCalendar.dateComponents([.year, .month, .day], from: remoteNow)
        components.hour = appState.inputHour
        components.minute = appState.inputMinute
        components.second = 0

        let sameDay = remoteCalendar.date(from: components) ?? remoteNow
        return remoteCalendar.date(byAdding: .day, value: appState.inputDayOffset, to: sameDay) ?? sameDay
    }
}
