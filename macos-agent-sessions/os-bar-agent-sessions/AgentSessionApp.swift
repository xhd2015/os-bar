import ApplicationServices
import SwiftUI
import ServiceManagement

@MainActor
final class OpenLogsController: ObservableObject {
    static let shared = OpenLogsController()

    @Published private(set) var finderLabel = "Show Logs in Finder"
    @Published private(set) var finderEnabled = false
    @Published private(set) var logsLabel = "Logs"
    @Published private(set) var logsEnabled = true

    private init() {}

    func refresh() async {
        do {
            _ = try await DaemonClient.shared.info()
            applyFinder(OpenLogsMenuState.menuState(infoError: nil))
        } catch {
            applyFinder(OpenLogsMenuState.menuState(infoError: error.localizedDescription))
        }
        applyLogs(OpenLogsMenuState.logsViewerMenuState())
    }

    func performOpenFinder() async {
        await refresh()
        guard finderEnabled else { return }
        await LogsFinderOpener.openLogs()
    }

    private func applyFinder(_ state: OpenLogsMenuStateResult) {
        finderLabel = state.label
        finderEnabled = state.enabled
    }

    private func applyLogs(_ state: OpenLogsMenuStateResult) {
        logsLabel = state.label
        logsEnabled = state.enabled
    }
}

@MainActor
final class DaemonReadiness: ObservableObject {
    static let shared = DaemonReadiness()

    @Published private(set) var isReady = false

    private init() {}

    func markReady() {
        isReady = true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: SessionStore?
    private var daemonProcess: Process?

    /// Tracks how many dir-open operations are in-flight so the loading cursor
    /// stays pushed until all complete (or their 3s timeouts expire).
    private var cursorPushCount = 0
    private var loadingCursor: NSCursor?

    func applicationWillTerminate(_ notification: Notification) {
        DaemonShutdown.terminateOnQuit(
            config: DaemonShutdown.agentSessions,
            spawnedProcess: daemonProcess
        )
        daemonProcess = nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingOpenSettings") {
            Task { @MainActor in
                await ensureUITestingDaemonRunning()
            }
            return
        }
        Task { @MainActor in
            await ensureDaemonRunning()
            await store?.refresh()
        }
    }

    @MainActor
    private func ensureUITestingDaemonRunning() async {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // UI automation helper pre-starts the daemon; never spawn here (avoids untracked orphans).
        for _ in 0..<30 {
            if (try? await DaemonClient.shared.health()) == true {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DaemonReadiness.shared.markReady()
    }

    @MainActor
    private func ensureDaemonRunning() async {
        defer { DaemonReadiness.shared.markReady() }
        if (try? await DaemonClient.shared.health()) == true {
            return
        }
        spawnDaemon()
        for _ in 0..<50 {
            if (try? await DaemonClient.shared.health()) == true {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        print("Warning: daemon health check failed after spawn")
    }

    private func spawnDaemon() {
        let binary = daemonBinaryPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        var args = ["serve"]
        let env = ProcessInfo.processInfo.environment
        if let port = env["AGENT_SESSIONS_PORT"] {
            args.append(contentsOf: ["--port", port])
        }
        if let stateDir = env["AGENT_SESSIONS_STATE_DIR"] {
            args.append(contentsOf: ["--state-dir", stateDir])
        }
        process.arguments = args
        process.environment = env
        do {
            try process.run()
            daemonProcess = process
        } catch {
            print("Failed to spawn daemon at \(binary): \(error)")
        }
    }

    private func daemonBinaryPath() -> String {
        if let cli = ProcessInfo.processInfo.environment["AGENT_SESSIONS_CLI"], !cli.isEmpty {
            return cli
        }
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/agent-sessions")
            .path
        if FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        return "/usr/local/bin/agent-sessions"
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
                Task {
                    try? await DaemonClient.shared.appendLog(entry)
                }
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
                Task {
                    try? await DaemonClient.shared.appendLog(entry)
                }
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

@available(macOS 15.0, *)
@main
struct AgentSessionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = SessionStore()
    @ObservedObject private var openLogs = OpenLogsController.shared
    @AppStorage("autoStart") private var autoStart = false

    init() {
        let store = SessionStore()
        _store = StateObject(wrappedValue: store)
        appDelegate.store = store
        store.configureNotifications(appDelegate: appDelegate)
        // Sync toggle with actual system state
        if #available(macOS 13.0, *) {
            _autoStart.wrappedValue = SMAppService.mainApp.status == .enabled
        }
    }

    var body: some Scene {
        Window("Integrations", id: "integrations") {
            IntegrationsSettingsView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Logs", id: "logs") {
            LogsViewerView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra {
            MenuBarDropdownContent(
                store: store,
                openLogs: openLogs,
                autoStart: $autoStart,
                showIntegrationsSettings: showIntegrationsSettings,
                showLogsWindow: showLogsWindow,
                openInCode: openInCode
            )
        } label: {
            ZStack {
                HStack(spacing: 2) {
                    Image(systemName: store.unconsumedCount > 0 ? "bell.badge" : "bell")
                        .imageScale(.small)
                    if store.unconsumedCount > 0 {
                        Text("\(store.unconsumedCount)")
                            .font(.system(size: 11))
                    }
                }
                .fixedSize()
                IntegrationsLauncher()
            }
            .accessibilityIdentifier("menu-bar-extra")
        }
        .commands {
            HelpMenuCommands(openLogs: openLogs)
        }
    }

    // MARK: - Helpers

    private func showLogsWindow(openWindow: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "logs")
        if let window = NSApp.windows.first(where: { $0.title == "Logs" }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        Task { @MainActor in
            for _ in 0..<15 {
                openWindow(id: "logs")
                if let window = NSApp.windows.first(where: { $0.title == "Logs" }) {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func showIntegrationsSettings(openWindow: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "integrations")
        if let window = NSApp.windows.first(where: { $0.title == "Integrations" }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        Task { @MainActor in
            for _ in 0..<15 {
                openWindow(id: "integrations")
                if let window = NSApp.windows.first(where: { $0.title == "Integrations" }) {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func openInCode(_ dir: String) {
        appDelegate.openDir(dir)
    }
}

@available(macOS 15.0, *)
private struct MenuBarDropdownContent: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var openLogs: OpenLogsController
    @Binding var autoStart: Bool
    @Environment(\.openWindow) private var openWindow
    let showIntegrationsSettings: (OpenWindowAction) -> Void
    let showLogsWindow: (OpenWindowAction) -> Void
    let openInCode: (String) -> Void

    var body: some View {
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
                        let time = store.relativeTime(for: event.timestamp)
                        Text(SessionMenuItemFormatter.displayLabel(
                            dir: event.dir,
                            consumed: event.consumed,
                            relativeTime: time
                        ))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .help(SessionMenuItemFormatter.tooltip(dir: event.dir))
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

            Button(openLogs.finderLabel) {
                Task { await openLogs.performOpenFinder() }
            }
            .disabled(!openLogs.finderEnabled)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)

            Button(openLogs.logsLabel) {
                showLogsWindow(openWindow)
            }
            .disabled(!openLogs.logsEnabled)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)

            SettingsMenuButton(showIntegrationsSettings: showIntegrationsSettings)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
        }
        .padding(.vertical, 4)
        .frame(minWidth: 220)
        .accessibilityIdentifier("menu-bar-extra")
        .task {
            while !DaemonReadiness.shared.isReady {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            await openLogs.refresh()
        }
        .onAppear {
            Task { await openLogs.refresh() }
        }
    }
}

@available(macOS 15.0, *)
private struct HelpMenuCommands: Commands {
    @ObservedObject var openLogs: OpenLogsController
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button(openLogs.finderLabel) {
                Task { await openLogs.performOpenFinder() }
            }
            .disabled(!openLogs.finderEnabled)

            Button(openLogs.logsLabel) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "logs")
            }
            .disabled(!openLogs.logsEnabled)
        }
    }
}

private struct IntegrationsLauncher: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var daemonReadiness = DaemonReadiness.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-uiTestingOpenSettings") else {
                    return
                }
                while !daemonReadiness.isReady {
                    try? await Task.sleep(nanoseconds: 25_000_000)
                }
                for _ in 0..<10 {
                    openWindow(id: "integrations")
                    if NSApp.windows.contains(where: { $0.title == "Integrations" }) {
                        return
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
    }
}

private struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    let showIntegrationsSettings: (OpenWindowAction) -> Void

    var body: some View {
        Button("Settings…") {
            showIntegrationsSettings(openWindow)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .accessibilityIdentifier("settings-menu-button")
    }
}
