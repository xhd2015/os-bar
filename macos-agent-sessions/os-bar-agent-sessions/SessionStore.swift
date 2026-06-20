import Foundation
import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var events: [SessionEvent] = []

    private let client = DaemonClient.shared
    private var pollTask: Task<Void, Never>?

    init() {
        startPolling()
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

    func refresh() async {
        do {
            events = try await client.listEvents()
        } catch {
            print("SessionStore: refresh failed: \(error)")
        }
    }

    func markConsumed(dir: String) {
        Task {
            do {
                try await client.consume(dir: dir)
                await refresh()
            } catch {
                print("SessionStore: consume failed: \(error)")
            }
        }
    }

    var unconsumedCount: Int {
        events.filter { !$0.consumed }.count
    }

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
}