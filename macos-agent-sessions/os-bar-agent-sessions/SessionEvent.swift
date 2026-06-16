import Foundation

struct SessionEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let dir: String
    let timestamp: Date
    var consumed: Bool

    init(dir: String, timestamp: Date = Date(), consumed: Bool = false) {
        self.id = UUID()
        self.dir = dir
        self.timestamp = timestamp
        self.consumed = consumed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dir = try container.decode(String.self, forKey: .dir)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        consumed = try container.decodeIfPresent(Bool.self, forKey: .consumed) ?? false
    }
}
