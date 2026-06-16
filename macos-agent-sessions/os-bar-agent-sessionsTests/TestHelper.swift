import Foundation
import Network

// ====================================================================
// Test Helper for os-bar-agent-sessions
//
// Reads a single JSON Request from stdin, executes the requested
// action, and prints a JSON Response to stdout.
//
// Compile: swiftc -o .build/test-helper TestHelper.swift
// ====================================================================

// MARK: - Models mirroring production types

struct SessionEvent: Codable, Equatable {
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

// MARK: - In-Memory SessionStore (for testing)

class TestSessionStore {
    var events: [SessionEvent] = []
    private let maxEvents = 20
    private let pruneInterval: TimeInterval = 7 * 24 * 3600

    // MARK: Add Event

    func addEvent(dir: String, timestamp: Date? = nil) {
        if let existingIndex = events.firstIndex(where: { $0.dir == dir }) {
            // Bump timestamp, reset consumed to false
            events[existingIndex] = SessionEvent(dir: dir, timestamp: timestamp ?? Date(), consumed: false)
        } else {
            events.append(SessionEvent(dir: dir, timestamp: timestamp ?? Date()))
        }
        sortAndCap()
    }

    // MARK: Mark Consumed

    func markConsumed(dir: String) {
        guard let index = events.firstIndex(where: { $0.dir == dir }) else { return }
        events[index].consumed = true
    }

    // MARK: Unconsumed Count

    var unconsumedCount: Int {
        events.filter { !$0.consumed }.count
    }

    // MARK: Prune

    func prune(reference: Date = Date()) {
        let cutoff = reference.addingTimeInterval(-pruneInterval)
        events = events.filter { $0.timestamp > cutoff }
        sortAndCap()
    }

    // MARK: Relative Time

    func relativeTime(for timestamp: Date, reference: Date = Date()) -> String {
        let diff = reference.timeIntervalSince(timestamp)

        if diff < 60 {
            return "<1m ago"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }

    // MARK: Private Helpers

    private func sortAndCap() {
        events.sort { $0.timestamp > $1.timestamp }
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }
}

// MARK: - JSON Request from test framework

struct Request: Codable {
    let action: String
    let dir: String?
    let dirs: [String]?
    let events_json: String?
    let timestamp_iso: String?
    let reference_iso: String?
    let http_method: String?
    let http_path: String?
    let http_body: String?
    let content_type: String?
}

// MARK: - JSON Response to test framework

struct EventResponse: Codable {
    let id: String
    let dir: String
    let timestamp: String
    let consumed: Bool
}

struct Response: Codable {
    var events: [EventResponse] = []
    var count: Int = 0
    var unconsumed_count: Int = 0
    var http_status: Int = 0
    var http_body: String = ""
    var relative_time: String = ""
    var error: String = ""
}

// MARK: - ISO8601 Date Helpers

let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func makeJSONDecoder() -> JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}

func makeJSONEncoder() -> JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}

func isoToString(_ date: Date) -> String {
    return iso8601Formatter.string(from: date)
}

func stringToIso(_ str: String) -> Date? {
    return iso8601Formatter.date(from: str)
}

func eventsToResponse(_ events: [SessionEvent]) -> [EventResponse] {
    return events.map { ev in
        EventResponse(
            id: ev.id.uuidString,
            dir: ev.dir,
            timestamp: isoToString(ev.timestamp),
            consumed: ev.consumed
        )
    }
}

// MARK: - Simple HTTP Server (using Network.framework)

class TestServer {
    private var listener: NWListener?
    private let store: TestSessionStore
    private(set) var port: UInt16 = 0
    private let serverQueue = DispatchQueue(label: "com.test.server")

    init(store: TestSessionStore) {
        self.store = store
    }

    func start() throws -> UInt16 {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        // Port 0 = ephemeral (OS assigns)
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        let semaphore = DispatchSemaphore(value: 0)

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.listener?.port?.rawValue {
                    self?.port = port
                }
                semaphore.signal()
            case .failed(let error):
                print("TestServer failed: \(error)")
                semaphore.signal()
            default:
                break
            }
        }

        listener?.start(queue: serverQueue)

        // Wait for server to be ready
        _ = semaphore.wait(timeout: .now() + 5)

        return port
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: serverQueue)
        var buffer = Data()

        func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                if let data = data {
                    buffer.append(data)
                }

                // Check if we have the full HTTP request
                if let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    let headerData = buffer.subdata(in: 0..<headerEndRange.lowerBound)
                    let headersStr = String(data: headerData, encoding: .utf8) ?? ""

                    // Parse content length
                    var contentLength = 0
                    let lines = headersStr.components(separatedBy: "\r\n")
                    for line in lines.dropFirst() {
                        let lower = line.lowercased()
                        if lower.hasPrefix("content-length:") {
                            let parts = line.components(separatedBy: ":")
                            if parts.count > 1 {
                                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                            }
                        }
                    }

                    let bodyStartIndex = headerEndRange.upperBound
                    if buffer.count - bodyStartIndex >= contentLength {
                        // We have the full body
                        let body = contentLength > 0 ? buffer.subdata(in: bodyStartIndex..<(bodyStartIndex + contentLength)) : Data()

                        if let firstLine = lines.first {
                            let parts = firstLine.components(separatedBy: " ")
                            let method = parts.count > 0 ? parts[0] : ""
                            let path = parts.count > 1 ? parts[1] : ""

                            let responseData = self?.handleRequest(method: method, path: path, body: body) ?? Data()
                            connection.send(content: responseData, completion: .contentProcessed({ _ in
                                connection.cancel()
                            }))
                            return
                        }
                    }
                }

                if isComplete || error != nil {
                    connection.cancel()
                    return
                }
                receive()
            }
        }

        receive()
    }

    // MARK: Request Handling

    private func handleRequest(method: String, path: String, body: Data) -> Data {
        // Check path
        if path != "/api/notify" {
            return httpResponse(status: 404, body: "{\"error\":\"not found\"}")
        }

        // Check method
        if method != "POST" {
            return httpResponse(status: 405, body: "{\"error\":\"method not allowed\"}")
        }

        // Parse JSON body
        let bodyStr = String(data: body, encoding: .utf8) ?? ""
        guard let bodyData = bodyStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        else {
            return httpResponse(status: 400, body: "{\"error\":\"invalid json\"}")
        }

        // Extract dir — must be present and non-empty
        guard let dir = json["dir"] as? String, !dir.isEmpty else {
            return httpResponse(status: 400, body: "{\"error\":\"missing or empty dir\"}")
        }

        // Store event
        store.addEvent(dir: dir)

        return httpResponse(status: 200, body: "{\"ok\":true}")
    }

    // MARK: HTTP Response Helper

    private func httpResponse(status: Int, body: String) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Unknown"
        }

        let bodyData = body.data(using: .utf8) ?? Data()
        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r
        \(body)
        """
        return response.data(using: .utf8) ?? Data()
    }
}

// MARK: - Main

func runHelper() -> Never {
    // Read a single JSON line from stdin
    guard let input = readLine() else {
        fputs("{\"error\":\"no input provided\"}\n", stderr)
        exit(1)
    }

    guard let jsonData = input.data(using: .utf8),
          let request = try? makeJSONDecoder().decode(Request.self, from: jsonData)
    else {
        fputs("{\"error\":\"invalid JSON input\"}\n", stderr)
        exit(1)
    }

    var response = Response()

    switch request.action {
    case "add_event":
        let store = TestSessionStore()

        // Preload if events_json is provided
        if let eventsJSON = request.events_json,
           let data = eventsJSON.data(using: .utf8),
           let preloaded = try? makeJSONDecoder().decode([SessionEvent].self, from: data) {
            store.events = preloaded
        }

        if let dir = request.dir {
            store.addEvent(dir: dir)
            response.events = eventsToResponse(store.events)
            response.count = store.events.count
            response.unconsumed_count = store.unconsumedCount
        } else {
            response.error = "missing dir for add_event"
        }

    case "add_events_batch":
        let store = TestSessionStore()

        // Preload if events_json is provided
        if let eventsJSON = request.events_json,
           let data = eventsJSON.data(using: .utf8),
           let preloaded = try? makeJSONDecoder().decode([SessionEvent].self, from: data) {
            store.events = preloaded
        }

        if let dirs = request.dirs {
            for dir in dirs {
                store.addEvent(dir: dir)
                // Small delay to ensure distinct deterministic timestamps
                usleep(2000)
            }
            response.events = eventsToResponse(store.events)
            response.count = store.events.count
            response.unconsumed_count = store.unconsumedCount
        } else {
            response.error = "missing dirs for add_events_batch"
        }

    case "prune":
        let store = TestSessionStore()

        if let eventsJSON = request.events_json,
           let data = eventsJSON.data(using: .utf8),
           let preloaded = try? makeJSONDecoder().decode([SessionEvent].self, from: data) {
            store.events = preloaded
            store.prune()
            response.events = eventsToResponse(store.events)
            response.count = store.events.count
            response.unconsumed_count = store.unconsumedCount
        } else {
            response.error = "missing events_json for prune"
        }

    case "relative_time":
        guard let tsISO = request.timestamp_iso,
              let timestamp = stringToIso(tsISO) else {
            response.error = "missing or invalid timestamp_iso"
            break
        }

        let reference: Date
        if let refISO = request.reference_iso,
           let ref = stringToIso(refISO) {
            reference = ref
        } else {
            reference = Date()
        }

        let store = TestSessionStore()
        response.relative_time = store.relativeTime(for: timestamp, reference: reference)

    case "server_post":
        let store = TestSessionStore()
        let server = TestServer(store: store)

        do {
            let port = try server.start()

            let httpMethod = request.http_method ?? "POST"
            let httpPath = request.http_path ?? "/api/notify"
            let httpBody = request.http_body ?? ""
            let contentType = request.content_type ?? "application/json"

            // Build URL request
            let urlStr = "http://127.0.0.1:\(port)\(httpPath)"
            guard let url = URL(string: urlStr) else {
                response.error = "invalid URL: \(urlStr)"
                server.stop()
                break
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = httpMethod
            if httpMethod != "GET" {
                urlRequest.httpBody = httpBody.data(using: .utf8)
                urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }

            let semaphore = DispatchSemaphore(value: 0)
            var httpStatus = 0
            var responseBody = ""
            var requestError: Error?

            let task = URLSession.shared.dataTask(with: urlRequest) { data, urlResp, error in
                defer { semaphore.signal() }

                if let error = error {
                    requestError = error
                    return
                }

                if let httpResponse = urlResp as? HTTPURLResponse {
                    httpStatus = httpResponse.statusCode
                }

                if let data = data {
                    responseBody = String(data: data, encoding: .utf8) ?? ""
                }
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + 10)

            server.stop()

            if let requestError = requestError {
                response.error = "HTTP request failed: \(requestError.localizedDescription)"
            } else {
                response.http_status = httpStatus
                response.http_body = responseBody
                response.events = eventsToResponse(store.events)
                response.count = store.events.count
                response.unconsumed_count = store.unconsumedCount
            }

        } catch {
            response.error = "server start failed: \(error.localizedDescription)"
            server.stop()
        }

    case "mark_consumed":
        let store = TestSessionStore()

        // Preload if events_json is provided
        if let eventsJSON = request.events_json,
           let data = eventsJSON.data(using: .utf8),
           let preloaded = try? makeJSONDecoder().decode([SessionEvent].self, from: data) {
            store.events = preloaded
        }

        if let dir = request.dir {
            store.markConsumed(dir: dir)
            response.events = eventsToResponse(store.events)
            response.count = store.events.count
            response.unconsumed_count = store.unconsumedCount
        } else {
            response.error = "missing dir for mark_consumed"
        }

    case "unconsumed_count":
        let store = TestSessionStore()

        if let eventsJSON = request.events_json,
           let data = eventsJSON.data(using: .utf8),
           let preloaded = try? makeJSONDecoder().decode([SessionEvent].self, from: data) {
            store.events = preloaded
            response.events = eventsToResponse(store.events)
            response.count = store.events.count
            response.unconsumed_count = store.unconsumedCount
        } else {
            response.error = "missing events_json for unconsumed_count"
        }

    default:
        response.error = "unknown action: \(request.action)"
    }

    // Encode and output
    guard let outputData = try? makeJSONEncoder().encode(response),
          let output = String(data: outputData, encoding: .utf8)
    else {
        fputs("{\"error\":\"failed to encode response\"}\n", stderr)
        exit(1)
    }

    print(output)
    fflush(stdout)
    exit(0)
}

runHelper()
