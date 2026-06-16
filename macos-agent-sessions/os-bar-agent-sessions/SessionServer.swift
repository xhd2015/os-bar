import Foundation
import Network
import AppKit

class SessionServer {
    private var listener: NWListener?
    private let store: SessionStore
    private let logStore = NotifyLogStore()
    private let port: UInt16

    init(store: SessionStore, port: UInt16 = 38271) {
        self.store = store
        self.port = port
    }

    // MARK: - Start

    func start() throws {
        // Check for port conflict
        if let existingPID = checkPortConflict(port: port) {
            let alert = NSAlert()
            alert.messageText = "Port \(port) In Use"
            alert.informativeText = "Another process (PID: \(existingPID)) is using port \(port). Do you want to kill it and continue?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Kill & Continue")
            alert.addButton(withTitle: "Exit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Kill the process
                let killTask = Process()
                killTask.launchPath = "/bin/kill"
                killTask.arguments = [existingPID]
                killTask.launch()
                killTask.waitUntilExit()

                // Wait a moment for port to free
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                NSApplication.shared.terminate(nil)
                return
            }
        }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let nwPort = NWEndpoint.Port(rawValue: port)!
        listener = try NWListener(using: params, on: nwPort)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                print("SessionServer listener failed: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Server Error"
                    alert.informativeText = "Failed to start server on port \(self.port): \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Exit")
                    alert.runModal()
                    NSApplication.shared.terminate(nil)
                }
            case .cancelled:
                print("SessionServer listener cancelled")
            case .ready:
                print("SessionServer listening on port \(self.port)")
            default:
                break
            }
        }

        listener?.start(queue: .main)
    }

    // MARK: - Stop

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
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

    // MARK: - Request Handling

    private func handleRequest(method: String, path: String, body: Data) -> Data {
        // GET /api/list — return all stored events
        if method == "GET" && path == "/api/list" {
            return handleList()
        }

        // GET /api/info — return server metadata
        if method == "GET" && path == "/api/info" {
            return handleInfo()
        }

        // DELETE /api/events?dir=<path> — remove events for a directory
        if method == "DELETE" && path.hasPrefix("/api/events") {
            return handleRemoveEvents(path: path)
        }

        // GET /api/logs — return notification log entries
        if method == "GET" && path == "/api/logs" {
            return handleLogs()
        }

        // POST /api/notify — store a session event
        if method == "POST" && path == "/api/notify" {
            return handleNotify(body: body)
        }

        // Unknown path
        if path != "/api/notify" && path != "/api/list" && path != "/api/info" && path != "/api/logs" && !path.hasPrefix("/api/events") {
            return httpResponse(status: 404, body: "{\"error\":\"not found\"}")
        }

        // Wrong method for known path
        return httpResponse(status: 405, body: "{\"error\":\"method not allowed\"}")
    }

    private func handleNotify(body: Data) -> Data {
        // Parse JSON body
        let bodyStr = String(data: body, encoding: .utf8) ?? ""
        guard let bodyData = bodyStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        else {
            return httpResponse(status: 400, body: "{\"error\":\"invalid json\"}")
        }

        // Extract dir
        guard let dir = json["dir"] as? String, !dir.isEmpty else {
            return httpResponse(status: 400, body: "{\"error\":\"missing or empty dir\"}")
        }

        // Extract extension-specific details for logging
        var piDetails: NotifyLogEntry.PiDetails? = nil
        if let pi = json["pi"] as? [String: Any] {
            piDetails = NotifyLogEntry.PiDetails(
                sessionId: pi["sessionId"] as? String,
                sessionName: pi["sessionName"] as? String,
                nativeEvent: pi["nativeEvent"] as? String
            )
        }
        var opencodeDetails: NotifyLogEntry.OpencodeDetails? = nil
        if let oc = json["opencode"] as? [String: Any] {
            opencodeDetails = NotifyLogEntry.OpencodeDetails(
                sessionId: oc["sessionId"] as? String,
                nativeEvent: oc["nativeEvent"] as? String
            )
        }

        // Log the notification
        let logEntry = NotifyLogEntry(
            timestamp: Date(),
            dir: dir,
            event: json["event"] as? String,
            pi: piDetails,
            opencode: opencodeDetails
        )
        logStore.append(logEntry)

        // Store event
        DispatchQueue.main.async { [weak self] in
            self?.store.addEvent(dir: dir)
        }

        return httpResponse(status: 200, body: "{\"ok\":true}")
    }

    private func handleList() -> Data {
        let apiEncoder = JSONEncoder()
        apiEncoder.dateEncodingStrategy = .iso8601

        do {
            let data = try apiEncoder.encode(store.events)
            let body = String(data: data, encoding: .utf8) ?? "[]"
            return httpResponse(status: 200, body: body)
        } catch {
            return httpResponse(status: 500, body: "{\"error\":\"failed to encode events\"}")
        }
    }

    private func handleInfo() -> Data {
        var storagePath = "UserDefaults"
        if let bundleID = Bundle.main.bundleIdentifier {
            let libDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? "~/Library"
            storagePath = "\(libDir)/Preferences/\(bundleID).plist"
        }
        let info: [String: Any] = [
            "storage_path": storagePath,
            "port": port,
            "event_count": store.events.count,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted),
           let body = String(data: data, encoding: .utf8) {
            return httpResponse(status: 200, body: body)
        }
        return httpResponse(status: 500, body: "{\"error\":\"failed to serialize info\"}")
    }

    private func handleLogs() -> Data {
        if let data = logStore.encodeEntries() {
            let body = String(data: data, encoding: .utf8) ?? "[]"
            return httpResponse(status: 200, body: body)
        }
        return httpResponse(status: 500, body: "{\"error\":\"failed to encode logs\"}")
    }

    private func handleRemoveEvents(path: String) -> Data {
        // Parse dir from query: /api/events?dir=<path>
        guard let queryStart = path.firstIndex(of: "?") else {
            return httpResponse(status: 400, body: "{\"error\":\"missing dir parameter\"}")
        }
        let query = String(path[path.index(after: queryStart)...])
        let params = query.components(separatedBy: "&").reduce(into: [String: String]()) { dict, pair in
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                dict[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
            }
        }
        guard let dir = params["dir"], !dir.isEmpty else {
            return httpResponse(status: 400, body: "{\"error\":\"missing dir parameter\"}")
        }

        let before = store.events.count
        store.removeEvents(dir: dir)
        let after = store.events.count
        let removed = before - after

        if removed == 0 {
            return httpResponse(status: 404, body: "{\"error\":\"no events found for dir\"}")
        }

        let body = "{\"ok\":true,\"removed\":\(removed)}"
        return httpResponse(status: 200, body: body)
    }

    // MARK: - HTTP Response Helper

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

    // MARK: - Port Conflict

    private func checkPortConflict(port: UInt16) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-ti", ":\(port)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output.isEmpty {
            return nil
        }

        // Get first PID
        return output.components(separatedBy: "\n").first
    }
}
