import Foundation

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

struct MetricsSnapshot: Decodable {
    let cpuPercent: Double
    let memPercent: Double

    enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case memPercent = "mem_percent"
    }
}

final class DaemonClient {
    static let shared = DaemonClient()

    let port: Int
    private let session: URLSession

    init(port: Int = 38270, session: URLSession = .shared) {
        self.port = port
        self.session = session
    }

    private var baseURL: String {
        "http://127.0.0.1:\(port)"
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

    func metrics() async throws -> MetricsSnapshot {
        let (data, response) = try await get(path: "/api/metrics")
        try ensureOK(response, data: data)
        do {
            return try JSONDecoder().decode(MetricsSnapshot.self, from: data)
        } catch {
            throw DaemonClientError.decodeFailed(error.localizedDescription)
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

    private func ensureOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DaemonClientError.unreachable("no HTTP response")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DaemonClientError.badStatus(http.statusCode, body)
        }
    }
}