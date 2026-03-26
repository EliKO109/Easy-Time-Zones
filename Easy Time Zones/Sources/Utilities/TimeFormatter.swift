import Foundation
import AppKit

enum TimeFormatter {
    private static var formatterCache: [String: DateFormatter] = [:]

    static func shortTimeString(from date: Date, timeZone: TimeZone, is24Hour: Bool = true) -> String {
        let formatter = formatter(
            template: is24Hour ? "HHmm" : "hmma",
            timeZone: timeZone
        )
        return formatter.string(from: date)
    }

    static func fullDateTimeString(from date: Date, timeZone: TimeZone, is24Hour: Bool = true) -> String {
        let formatter = formatter(
            template: is24Hour ? "MMMdHHmm" : "MMMdhmma",
            timeZone: timeZone
        )
        return formatter.string(from: date)
    }

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func formatter(template: String, timeZone: TimeZone) -> DateFormatter {
        let cacheKey = "\(template)|\(timeZone.identifier)"

        if let cachedFormatter = formatterCache[cacheKey] {
            return cachedFormatter
        }

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatterCache[cacheKey] = formatter
        return formatter
    }
}
