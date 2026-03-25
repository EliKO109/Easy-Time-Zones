import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Label(
                TimeFormatter.shortTimeString(from: timeline.date, timeZone: appState.homeTimeZone, is24Hour: appState.use24HourFormat),
                systemImage: "clock.fill"
            )
            .foregroundStyle(Brand.primary)
        }
    }
}
