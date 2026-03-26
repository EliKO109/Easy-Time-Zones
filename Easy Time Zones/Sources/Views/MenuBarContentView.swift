import SwiftUI
import MapKit

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var sliderValue: Double = 0
    @State private var localManualTime: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            VStack(spacing: 0) {
                headerSection
                Divider()
                scrollContent
            }
            .frame(width: 300)
            .onAppear {
                sliderValue = Double(appState.timeOffsetSteps)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(appState.homeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    if !appState.isLiveNow {
                        Text("TRAVELING")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(appState.accentColor, in: RoundedRectangle(cornerRadius: 4))
                    } else {
                        Circle()
                            .fill(.green)
                            .frame(width: 4, height: 4)
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(TimeFormatter.shortTimeString(
                    from: appState.referenceDate,
                    timeZone: appState.homeTimeZone,
                    is24Hour: appState.use24HourFormat))
                    .font(.system(size: 32, weight: .light).monospacedDigit())
                    .foregroundStyle(appState.isLiveNow ? Color.primary : appState.accentColor)
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(gmtOffsetText(for: appState.homeTimeZone, now: appState.referenceDate))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)

                Text(dayPhase(for: appState.referenceDate, in: appState.homeTimeZone))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(appState.isLiveNow ? Color.primary.opacity(0.3) : appState.accentColor.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(appState.isLiveNow ? Color.clear : appState.accentColor.opacity(0.03))
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                locationsSection
                    .padding(.bottom, 8)

                Divider()

                converterSection
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 8)

                footerActions
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Locations", systemImage: "globe")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { 
                    appState.autoDetectLocation.toggle()
                }) {
                    Image(systemName: appState.autoDetectLocation ? "location.fill" : "location")
                        .font(.caption)
                        .foregroundStyle(appState.autoDetectLocation ? appState.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Auto-detect Home Location")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    if appState.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    TextField("Add city…", text: $appState.draftSearchText)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .onSubmit { appState.addLocationFromSearch() }
                        .onChange(of: appState.draftSearchText) { _, newValue in
                            appState.updateSearchQuery(newValue)
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 6))

                if !appState.searchSuggestions.isEmpty && !appState.draftSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.searchSuggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                appState.addLocation(from: suggestion)
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
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(6)
                    .shadow(radius: 2)
                    .padding(.top, 4)
                }
            }

            if let err = appState.addLocationError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }

            if appState.savedLocations.isEmpty {
                Text("No tracked locations")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(appState.savedLocations) { location in
                    locationRow(for: location)
                }
            }
        }
    }

    private var converterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Converter", systemImage: "clock.arrow.2.circlepath")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                
                HStack(spacing: 6) {
                    Picker("", selection: $appState.useHomeAsBase) {
                        Image(systemName: "house").tag(true)
                        Image(systemName: "mappin.circle").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 46)
                    .controlSize(.mini)
                    .help(appState.useHomeAsBase ? "Using Home as base" : "Using Selected Location as base")

                    TextField("HH:MM", text: $localManualTime)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isFieldFocused ? appState.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                        .focused($isFieldFocused)
                        .onChange(of: localManualTime) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 4 {
                                localManualTime = String(filtered.prefix(4))
                                return
                            }
                            if filtered.count >= 3 {
                                let hStr = filtered.prefix(filtered.count - 2)
                                let mStr = filtered.suffix(2)
                                let formatted = "\(hStr):\(mStr)"
                                if localManualTime != formatted { localManualTime = formatted }
                            } else {
                                if localManualTime != filtered { localManualTime = filtered }
                            }
                        }
                        .onSubmit {
                            guard !localManualTime.isEmpty else { return }
                            appState.manualTimeInput = localManualTime
                            appState.applyManualTime()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                sliderValue = Double(appState.timeOffsetSteps)
                                localManualTime = appState.manualTimeInput
                            }
                        }

                    if !appState.isLiveNow {
                        HStack(spacing: 4) {
                            Text(offsetLabel)
                                .font(.system(size: 9, weight: .bold).monospaced())
                                .foregroundStyle(appState.accentColor)
                                .fixedSize()
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    appState.timeOffsetSteps = 0
                                    sliderValue = 0
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading, 2)
                    } else {
                        Text("Now")
                            .font(.system(size: 9, weight: .bold).monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.leading, 2)
                    }
                }
            }
            .padding(.horizontal, 4)

            Slider(
                value: $sliderValue,
                in: -48...48,
                step: 1
            )
            .accentColor(appState.isLiveNow ? .secondary : appState.accentColor)
            .padding(.horizontal, 4)
            .onChange(of: sliderValue) { _, newVal in
                appState.timeOffsetSteps = Int(newVal.rounded())
                localManualTime = ""
            }

            if let remote = appState.selectedRemote {
                let ref = appState.referenceDate
                let remoteTime = TimeFormatter.fullDateTimeString(
                    from: ref, timeZone: remote.timeZone,
                    is24Hour: appState.use24HourFormat)
                let homeTime = TimeFormatter.fullDateTimeString(
                    from: ref, timeZone: appState.homeTimeZone,
                    is24Hour: appState.use24HourFormat)

                VStack(spacing: 8) {
                    conversionRow(title: remote.name, time: remoteTime, isHome: appStoreIsBase(isHome: false))
                    Divider().opacity(0.5)
                    conversionRow(title: "Home", time: homeTime, isHome: appStoreIsBase(isHome: true))
                }
                .padding(10)
                .background(
                    appState.isLiveNow 
                        ? Color.primary.opacity(0.04) 
                        : appState.accentColor.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(appState.isLiveNow ? Color.clear : appState.accentColor.opacity(0.2), lineWidth: 1)
                )

                Button {
                    TimeFormatter.copyToClipboard(
                        "\(remote.name): \(remoteTime)\nHome: \(homeTime)"
                    )
                } label: {
                    Label("Copy Summary", systemImage: "doc.on.doc")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(appState.isLiveNow ? .secondary : appState.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            appState.isLiveNow 
                                ? Color.primary.opacity(0.05) 
                                : appState.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Text("Select a location above to see conversion")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 8)
    }

    private func appStoreIsBase(isHome: Bool) -> Bool {
        return appState.useHomeAsBase == isHome
    }

    private var footerActions: some View {
        VStack(spacing: 0) {
            SettingsLink {
                HStack {
                    Label("Settings…", systemImage: "gearshape")
                        .font(.subheadline)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(HoverBackground())

            footerButton(title: "Quit", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func locationRow(for location: SavedLocation) -> some View {
        let isSelected = location.id == appState.selectedRemoteID
        let displayDate = appState.referenceDate

        return Button {
            appState.selectedRemoteID = location.id
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(location.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? appState.accentColor : .primary)
                    Text(location.timeZoneID)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(TimeFormatter.shortTimeString(
                        from: displayDate,
                        timeZone: location.timeZone,
                        is24Hour: appState.use24HourFormat))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(isSelected ? appState.accentColor : .primary)

                    Text(offsetDifferenceText(
                        for: location.timeZone,
                        reference: appState.homeTimeZone,
                        now: displayDate))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(isSelected ? appState.accentColor.opacity(0.8) : .secondary)
                }
                .padding(.trailing, isSelected ? 8 : 0)

                if isSelected {
                    Button {
                        appState.removeLocation(location)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary.opacity(0.5))
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                isSelected
                    ? Color.primary.opacity(0.05)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private func conversionRow(title: String, time: String, isHome: Bool) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(isHome ? .bold : .medium))
                .foregroundStyle(isHome ? .primary : .secondary)
            Spacer()
            Text(time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(isHome ? appState.accentColor : .secondary)
        }
    }

    private func footerButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(HoverBackground())
    }

    private var offsetLabel: String {
        guard !appState.isLiveNow else { return "Now" }
        let steps = appState.timeOffsetSteps
        let sign = steps > 0 ? "+" : ""
        let hours = abs(steps) / 2
        let mins  = (abs(steps) % 2) * 30
        if mins == 0 {
            return "\(sign)\(steps > 0 ? "" : "-")\(hours)h"
        } else {
            return "\(sign)\(steps > 0 ? "" : "-")\(hours)h 30m"
        }
    }

    private func dayPhase(for date: Date, in timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        switch cal.component(.hour, from: date) {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default:      return "Night"
        }
    }

    private func gmtOffsetText(for timeZone: TimeZone, now: Date) -> String {
        let secs = timeZone.secondsFromGMT(for: now)
        let h = secs / 3600
        let m = abs(secs / 60) % 60
        return String(format: "GMT%+d:%02d", h, m)
    }

    private func offsetDifferenceText(for timeZone: TimeZone, reference: TimeZone, now: Date) -> String {
        let delta = timeZone.secondsFromGMT(for: now) - reference.secondsFromGMT(for: now)
        let sign  = delta >= 0 ? "+" : "-"
        let abs   = Swift.abs(delta)
        let h = abs / 3600
        let m = (abs / 60) % 60
        return String(format: "%@%dh %02dm vs home", sign, h, m)
    }
}

struct HoverBackground: View {
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            .onHover { isHovered = $0 }
    }
}
