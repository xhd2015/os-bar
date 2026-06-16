import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: SessionStore?
    var server: SessionServer?

    /// Tracks how many dir-open operations are in-flight so the loading cursor
    /// stays pushed until all complete (or their 3s timeouts expire).
    private var cursorPushCount = 0
    private var loadingCursor: NSCursor?

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

    // MARK: - Open Directory

    /// Launch `/usr/local/bin/code <dir>`, show a loading cursor while running
    /// (auto-dismiss after 3 s), and log exit code / stdout / stderr.
    func openDir(_ dir: String) {
        pushLoadingCursor()

        let startTime = Date()
        let process = Process()
        process.launchPath = "/usr/local/bin/code"
        process.arguments = [dir]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        var stdoutData = Data()
        var stderrData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { stdoutData.append(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { stderrData.append(data) }
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let timeoutWork = DispatchWorkItem { [weak self] in
            self?.popLoadingCursor()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeoutWork)

        process.terminationHandler = { [weak self] proc in
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                timeoutWork.cancel()
                self?.popLoadingCursor()

                let entry = NotifyLogEntry(
                    source: "log",
                    timestamp: Date(),
                    dir: dir,
                    event: "command.executed",
                    pi: nil,
                    opencode: nil,
                    command: NotifyLogEntry.CommandLogDetails(
                        command: "/usr/local/bin/code \(dir)",
                        exitCode: proc.terminationStatus,
                        stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                        stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                        durationMs: durationMs
                    )
                )
                NotifyLogStore.shared.append(entry)
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                timeoutWork.cancel()
                self?.popLoadingCursor()

                let entry = NotifyLogEntry(
                    source: "log",
                    timestamp: Date(),
                    dir: dir,
                    event: "command.error",
                    pi: nil,
                    opencode: nil,
                    command: NotifyLogEntry.CommandLogDetails(
                        command: "/usr/local/bin/code \(dir)",
                        exitCode: -1,
                        stdout: "",
                        stderr: "failed to launch: \(error.localizedDescription)",
                        durationMs: 0
                    )
                )
                NotifyLogStore.shared.append(entry)
            }
        }
    }

    // MARK: - Loading Cursor

    private func pushLoadingCursor() {
        if cursorPushCount == 0 {
            if loadingCursor == nil {
                guard let img = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Loading") else { return }
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                guard let configured = img.withSymbolConfiguration(config) else { return }
                loadingCursor = NSCursor(image: configured, hotSpot: NSPoint(x: 0, y: 0))
            }
            loadingCursor?.push()
        }
        cursorPushCount += 1
    }

    private func popLoadingCursor() {
        guard cursorPushCount > 0 else { return }
        cursorPushCount -= 1
        if cursorPushCount == 0 {
            NSCursor.pop()
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
                if store.unconsumedCount > 0 {
                    Text("\(store.unconsumedCount)")
                        .font(.system(size: 11))
                }
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
        appDelegate.openDir(dir)
    }
}
