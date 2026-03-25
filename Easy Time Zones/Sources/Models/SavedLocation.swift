import Foundation

struct SavedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var timeZoneID: String

    init(id: UUID = UUID(), name: String, timeZoneID: String) {
        self.id = id
        self.name = name
        self.timeZoneID = timeZoneID
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }
}
