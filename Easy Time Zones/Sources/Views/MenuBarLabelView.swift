import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "globe")
            
            if let menuBarTzID = appState.menuBarTimeZoneID,
               let tz = TimeZone(identifier: menuBarTzID) {
                Text(TimeFormatter.shortTimeString(
                    from: Date(),
                    timeZone: tz,
                    is24Hour: appState.use24HourFormat
                ))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
        }
    }
}
