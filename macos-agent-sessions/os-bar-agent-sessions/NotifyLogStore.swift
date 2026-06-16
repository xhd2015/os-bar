import Foundation

/// A log entry recorded when the server receives a notification or runs a command.
/// - `source: "notify"` → external notification (pushes to menu bar).
/// - `source: "log"` → locally executed command (log-only, no menu bar item).
struct NotifyLogEntry: Codable {
    let source: String
    let timestamp: Date
    let dir: String
    let event: String?
    let pi: PiDetails?
    let opencode: OpencodeDetails?
    var command: CommandLogDetails? = nil

    struct PiDetails: Codable {
        let sessionId: String?
        let sessionName: String?
        let nativeEvent: String?
    }

    struct OpencodeDetails: Codable {
        let sessionId: String?
        let nativeEvent: String?
    }

    /// Execution details captured when the app runs a shell command (e.g. `code /path`).
    struct CommandLogDetails: Codable {
        let command: String
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let durationMs: Int
    }
}

/// Stores notification and command-execution log entries for debugging.
class NotifyLogStore {
    static let shared = NotifyLogStore()

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
