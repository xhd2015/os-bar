import Foundation

/// A log entry recorded when the server receives a notification.
struct NotifyLogEntry: Codable {
    let timestamp: Date
    let dir: String
    let event: String?
    let pi: PiDetails?
    let opencode: OpencodeDetails?

    struct PiDetails: Codable {
        let sessionId: String?
        let sessionName: String?
        let nativeEvent: String?
    }

    struct OpencodeDetails: Codable {
        let sessionId: String?
        let nativeEvent: String?
    }
}

/// Stores notification log entries for debugging.
class NotifyLogStore {
    private var entries: [NotifyLogEntry] = []
    private let maxEntries = 200
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func append(_ entry: NotifyLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
    }

    func allEntries() -> [NotifyLogEntry] {
        return entries
    }

    func encodeEntries() -> Data? {
        return try? encoder.encode(entries)
    }
}
