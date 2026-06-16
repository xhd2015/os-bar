import Foundation
import Combine

class SessionStore: ObservableObject {
    @Published var events: [SessionEvent] = []

    private let userDefaultsKey = "sessionEvents"
    private let maxEvents = 20
    private let pruneInterval: TimeInterval = 7 * 24 * 3600

    init() {
        load()
    }

    // MARK: - Add Event

    func addEvent(dir: String) {
        if let existingIndex = events.firstIndex(where: { $0.dir == dir }) {
            // Update timestamp to now (bump), reset consumed to false
            events[existingIndex] = SessionEvent(dir: dir, timestamp: Date(), consumed: false)
        } else {
            events.append(SessionEvent(dir: dir))
        }
        sortAndCap()
        save()
    }

    // MARK: - Mark Consumed

    func markConsumed(dir: String) {
        guard let index = events.firstIndex(where: { $0.dir == dir }) else { return }
        events[index].consumed = true
        save()
    }

    // MARK: - Remove Events

    func removeEvents(dir: String) {
        let before = events.count
        events.removeAll { $0.dir == dir }
        if events.count != before {
            save()
        }
    }

    // MARK: - Unconsumed Count

    var unconsumedCount: Int {
        events.filter { !$0.consumed }.count
    }

    // MARK: - Load

    func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            events = []
            return
        }
        do {
            let loaded = try JSONDecoder().decode([SessionEvent].self, from: data)
            events = pruneAndSort(loaded)
        } catch {
            events = []
        }
    }

    // MARK: - Save

    func save() {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("SessionStore: failed to save events: \(error)")
        }
    }

    // MARK: - Relative Time

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

    // MARK: - Private Helpers

    private func sortAndCap() {
        events.sort { $0.timestamp > $1.timestamp }
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }

    private func pruneAndSort(_ loaded: [SessionEvent]) -> [SessionEvent] {
        let cutoff = Date().addingTimeInterval(-pruneInterval)
        let pruned = loaded.filter { $0.timestamp > cutoff }
        let capped = pruned.count > maxEvents ? Array(pruned.sorted { $0.timestamp > $1.timestamp }.prefix(maxEvents)) : pruned
        return capped.sorted { $0.timestamp > $1.timestamp }
    }
}
