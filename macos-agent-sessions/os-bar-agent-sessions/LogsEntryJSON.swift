import Foundation

enum LogsEntryJSON {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static func prettify(entry: NotifyLogEntry) throws -> String {
        let data = try encoder.encode(entry)
        guard let string = String(data: data, encoding: .utf8) else {
            throw LogsEntryJSONError.encodingFailed
        }
        return unescapeSlashes(string)
    }

    private static func unescapeSlashes(_ json: String) -> String {
        json.replacingOccurrences(of: "\\/", with: "/")
    }
}

enum LogsEntryJSONError: Error {
    case encodingFailed
}