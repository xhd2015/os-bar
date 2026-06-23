import Foundation

struct IntegrationItem: Identifiable, Equatable {
    let id: String
    let displayName: String
    let status: String
    let path: String
    let scope: String

    var badgeTitle: String {
        switch status {
        case "missing": return "Missing"
        case "up_to_date": return "Up to date"
        case "outdated": return "Outdated"
        case "installed": return "Installed"
        default: return status
        }
    }

    var showsInstallButton: Bool {
        status != "up_to_date"
    }
}

@MainActor
final class IntegrationsViewModel: ObservableObject {
    @Published private(set) var integrations: [IntegrationItem] = []
    @Published private(set) var isInstalling = false
    @Published private(set) var lastError: String?

    private let client = DaemonClient.shared
    private let useGlobalScope: Bool

    init(global: Bool = true) {
        useGlobalScope = global
    }

    func refresh() {
        lastError = nil
        Task {
            for attempt in 0..<10 {
                do {
                    integrations = try await client.integrations(global: useGlobalScope)
                    lastError = nil
                    return
                } catch where attempt == 9 {
                    lastError = error.localizedDescription
                } catch {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }
    }

    func install(target: String) {
        isInstalling = true
        lastError = nil
        Task {
            defer { isInstalling = false }
            do {
                try await client.installIntegration(target: target, global: useGlobalScope)
                integrations = try await client.integrations(global: useGlobalScope)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}