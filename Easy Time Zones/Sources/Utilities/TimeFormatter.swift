import Foundation
import AppKit

enum TimeFormatter {
    static func shortTimeString(from date: Date, timeZone: TimeZone, is24Hour: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(is24Hour ? "HHmm" : "hmma")
        return formatter.string(from: date)
    }

    static func fullDateTimeString(from date: Date, timeZone: TimeZone, is24Hour: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.setLocalizedDateFormatFromTemplate(is24Hour ? "MMMdHHmm" : "MMMdh mma")
        return formatter.string(from: date)
    }

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
