import Foundation

struct DaemonInfo: Decodable {
    let storagePath: String
    let port: Int?
    let eventCount: Int?

    enum CodingKeys: String, CodingKey {
        case storagePath = "storage_path"
        case port
        case eventCount = "event_count"
    }
}

enum DaemonClientError: LocalizedError {
    case unreachable(String)
    case badStatus(Int, String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let detail):
            return "daemon unreachable: \(detail)"
        case .badStatus(let code, let body):
            return "daemon returned \(code): \(body)"
        case .decodeFailed(let detail):
            return "failed to decode daemon response: \(detail)"
        }
    }
}

final class DaemonClient {
    static let shared = DaemonClient()

    let port: Int
    private let session: URLSession

    init(port: Int? = nil, session: URLSession = .shared) {
        if let port {
            self.port = port
        } else if let envPort = ProcessInfo.processInfo.environment["AGENT_SESSIONS_PORT"],
                  let parsed = Int(envPort) {
            self.port = parsed
        } else {
            self.port = 38271
        }
        self.session = session
    }

    private var baseURL: String {
        "http://127.0.0.1:\(port)"
    }

    func info() async throws -> DaemonInfo {
        let (data, response) = try await get(path: "/api/info")
        try ensureOK(response, data: data)
        do {
            return try JSONDecoder().decode(DaemonInfo.self, from: data)
        } catch {
            throw DaemonClientError.decodeFailed(error.localizedDescription)
        }
    }

    func health() async throws -> Bool {
        let (data, response) = try await get(path: "/api/health")
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DaemonClientError.unreachable("health check failed")
        }
        struct Payload: Decodable { let ok: Bool }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.ok
    }

    func listEvents() async throws -> [SessionEvent] {
        let (data, response) = try await get(path: "/api/list")
        try ensureOK(response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        return try decoder.decode([SessionEvent].self, from: data)
    }

    func listLogs() async throws -> [NotifyLogEntry] {
        let (data, response) = try await get(path: "/api/logs")
        try ensureOK(response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        return try decoder.decode([NotifyLogEntry].self, from: data)
    }

    func consume(dir: String) async throws {
        let body = try JSONEncoder().encode(["dir": dir])
        let (_, response) = try await post(path: "/api/events/consume", body: body)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DaemonClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1, "")
        }
    }

    func appendLog(_ entry: NotifyLogEntry) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(entry)
        let (_, response) = try await post(path: "/api/notify", body: body)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DaemonClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1, "")
        }
    }

    func integrations(global: Bool = true) async throws -> [IntegrationItem] {
        let path = global ? "/api/integrations?global=1" : "/api/integrations"
        let (data, response) = try await get(path: path)
        try ensureOK(response, data: data)

        struct Payload: Decodable {
            struct Entry: Decodable {
                let id: String
                let status: String
                let path: String
                let scope: String
            }
            let integrations: [Entry]
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let names: [String: String] = [
            "grok": "Grok",
            "opencode": "OpenCode",
            "pi": "Pi",
            "codex": "Codex",
        ]
        return payload.integrations.map { entry in
            IntegrationItem(
                id: entry.id,
                displayName: names[entry.id] ?? entry.id,
                status: entry.status,
                path: entry.path,
                scope: entry.scope
            )
        }
    }

    func installIntegration(target: String, global: Bool = true) async throws {
        struct Request: Encodable {
            let target: String
            let global: Bool
        }
        let body = try JSONEncoder().encode(Request(target: target, global: global))
        let (_, response) = try await post(path: "/api/integrations/install", body: body)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DaemonClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1, "")
        }
    }

    private func get(path: String) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw DaemonClientError.unreachable("invalid URL")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        return try await session.data(for: request)
    }

    private func post(path: String, body: Data) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw DaemonClientError.unreachable("invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 5
        return try await session.data(for: request)
    }

    private func ensureOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DaemonClientError.unreachable("no HTTP response")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DaemonClientError.badStatus(http.statusCode, body)
        }
    }

    private func decodeFlexibleDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "invalid date: \(value)")
    }
}