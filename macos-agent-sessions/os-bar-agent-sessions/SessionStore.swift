import Foundation
import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var events: [SessionEvent] = []

    private let client = DaemonClient.shared
    private let notificationService = SessionNotificationService()
    private var pollTask: Task<Void, Never>?

    func configureNotifications(appDelegate: AppDelegate) {
        notificationService.configure(appDelegate: appDelegate)
    }

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
            let previous = events
            let newEvents = try await client.listEvents()
            events = newEvents
            await notificationService.handleRefresh(previous: previous, current: newEvents)
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