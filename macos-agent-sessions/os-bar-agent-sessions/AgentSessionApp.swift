import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: SessionStore?
    var server: SessionServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let store = store else { return }
        let srv = SessionServer(store: store)
        do {
            try srv.start()
            server = srv
        } catch {
            print("Failed to start server: \(error)")
            let alert = NSAlert()
            alert.messageText = "Server Error"
            alert.informativeText = "Failed to start HTTP server: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Exit")
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }
}

@main
struct AgentSessionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = SessionStore()
    @AppStorage("autoStart") private var autoStart = false

    init() {
        let store = SessionStore()
        _store = StateObject(wrappedValue: store)
        appDelegate.store = store
        // Sync toggle with actual system state
        if #available(macOS 13.0, *) {
            _autoStart.wrappedValue = SMAppService.mainApp.status == .enabled
        }
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 0) {
                if store.events.isEmpty {
                    Text("No sessions")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                } else {
                    ForEach(store.events) { event in
                        Button {
                            openInCode(event.dir)
                            store.markConsumed(dir: event.dir)
                        } label: {
                            let dot = event.consumed ? "  " : "● "
                            let name = basename(event.dir).padding(toLength: 22, withPad: " ", startingAt: 0)
                            let time = store.relativeTime(for: event.timestamp)
                            Text("\(dot)\(name) \(time)")
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Toggle("Auto Start", isOn: $autoStart)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .onChange(of: autoStart) { enabled in
                        if #available(macOS 13.0, *) {
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Auto Start toggle failed: \(error)")
                                autoStart = !enabled
                            }
                        }
                    }

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
            }
            .padding(.vertical, 4)
            .frame(minWidth: 220)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: store.unconsumedCount > 0 ? "bell.badge" : "bell")
                    .imageScale(.small)
                Text("\(store.unconsumedCount)")
                    .font(.system(size: 11))
            }
            .fixedSize()
        }
    }

    // MARK: - Helpers

    private func basename(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    private func openInCode(_ dir: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["code", dir]
        task.launch()
    }
}
