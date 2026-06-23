import Foundation

enum LogsEntryFormatter {
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func formatDisplayLine(for entry: NotifyLogEntry) -> String {
        let basename = URL(fileURLWithPath: entry.dir).lastPathComponent
        let timestamp = timestampFormatter.string(from: entry.timestamp)
        let eventPart = entry.event.map { " \($0)" } ?? ""
        return "\(timestamp) \(entry.source) \(basename)\(eventPart)"
    }

    static func formatCommandDetails(for entry: NotifyLogEntry) -> [String] {
        guard entry.event == "command.executed", let command = entry.command else {
            return []
        }
        return [
            "command: \(command.command)",
            "exit code: \(command.exitCode)",
            "duration: \(command.durationMs)ms",
            "stdout: \(ioDisplayText(command.stdout))",
            "stderr: \(ioDisplayText(command.stderr))",
        ]
    }

    private static func ioDisplayText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(empty)" : trimmed
    }
}

@MainActor
final class LogsViewModel: ObservableObject {
    @Published private(set) var entries: [NotifyLogEntry] = []
    @Published private(set) var errorMessage: String?

    private let client: DaemonClient
    private var pollTask: Task<Void, Never>?

    init(client: DaemonClient = .shared) {
        self.client = client
    }

    deinit {
        pollTask?.cancel()
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        do {
            entries = try await client.listLogs()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func simulatePollDetection(entryCounts: [Int]) -> (counts: [Int], detectedNew: Bool) {
        var detectedNew = false
        var previousCount: Int?
        for count in entryCounts {
            if let previousCount, count > previousCount {
                detectedNew = true
            }
            previousCount = count
        }
        return (entryCounts, detectedNew)
    }
}