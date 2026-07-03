import AppKit
import ApplicationServices
import Darwin
import Foundation

// ====================================================================
// UI Automation Helper for os-bar-agent-sessions Integrations window
//
// Reads a single JSON Request from stdin, executes the requested
// action, and prints a JSON Response to stdout.
//
// Compile: swiftc -o .build/ui-automation-helper UIAutomationHelper.swift
// ====================================================================

struct AXFrame: Codable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct AXNode: Codable {
    let role: String
    var title: String?
    var identifier: String?
    var value: String?
    var frame: AXFrame?
    var children: [AXNode]?
}

struct Request: Codable {
    let action: String
    var home_dir: String?
    var work_dir: String?
    var identifier: String?
    var role: String?
    var title: String?
    var target: String?
    var global: Bool?
    var wait_ms: Int?
    var sequence: [Request]?
    var notify_dir: String?
    var notification_title: String?
    var log_capture_seconds: Int?
    var manual_click_wait_seconds: Int?
    var state_dir: String?
}

struct Response: Codable {
    var layout: AXNode?
    var layout_before: AXNode?
    var layout_after: AXNode?
    var window_open: Bool = false
    var window_visible: Bool = false
    var window_main: Bool = false
    var app_frontmost: Bool = false
    var click_x: Double?
    var click_y: Double?
    var click_ok: Bool = false
    var home_dir: String = ""
    var work_dir: String = ""
    var error: String = ""
    var notification_posted: Bool = false
    var notification_clicked: Bool = false
    var log_lines: [String] = []
    var notification_click_log_lines: [String] = []
    var vscode_log_lines: [String] = []
    var app_log_path: String = ""
    var app_log_lines: [String] = []
    var notification_authorized: Bool = false
    var notification_auth_status: String = ""
    var notification_bundle_id: String = ""
    var daemon_port: Int = 0
    var daemon_event_count: Int = 0
    var daemon_has_notify_event: Bool = false
    var app_saw_notification_posted: Bool = false
    var first_notification_clicked: Bool = false
    var second_notification_clicked: Bool = false
    var user_confirmed_window_opened: Bool = false
    var user_confirmed_desktop_ready: Bool = false
    var user_confirmed_correct_window: Bool = false
    var user_report_window_opened: String = ""
    var user_report_desktop_ready: String = ""
    var user_report_correct_window: String = ""
    var human_assisted_passed: Bool = false
}

final class UIAutomationSession {
    static let shared = UIAutomationSession()

    private(set) var appProcess: Process?
    private(set) var appPID: pid_t = 0
    private var daemonProcess: Process?
    private var daemonPID: pid_t = 0
    private var integrationsWindow: AXUIElement?
    private var dumpCount = 0
    private var projectRoot = ""
    private var cliPath = ""
    private var daemonPort = 0
    private var stateDir = ""
    private var useAppBundle = false
    private var captureAppOutput = false
    private var appLogPath = ""

    private init() {}

    func resetDumpCount() {
        dumpCount = 0
    }

    func configure(homeDir: String, workDir: String, stateDir: String? = nil) throws {
        projectRoot = try Self.findProjectRoot()
        cliPath = try Self.buildCLI(projectRoot: projectRoot)
        daemonPort = try Self.pickEphemeralPort()
        if let stateDir, !stateDir.isEmpty {
            self.stateDir = stateDir
        }
        _ = homeDir
        _ = workDir
    }

    func openSettings(homeDir: String) throws {
        try launchApp(homeDir: homeDir, uiTestingOpenSettings: true)
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if try integrationsReady() {
                usleep(100_000)
                return
            }
            usleep(50_000)
        }
        throw AutomationError.timeout("Integrations window did not become ready within 15s")
    }

    func configureNotificationUITest(homeDir: String, stateDir: String?, captureAppOutput: Bool) {
        useAppBundle = true
        self.captureAppOutput = captureAppOutput
        if let stateDir, !stateDir.isEmpty {
            appLogPath = (stateDir as NSString).appendingPathComponent("notification-click-ui.log")
        } else {
            appLogPath = (homeDir as NSString).appendingPathComponent(".os-bar/notification-click-ui.log")
        }
    }

    func launchApp(homeDir: String) throws {
        try launchApp(homeDir: homeDir, uiTestingOpenSettings: false)
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let appRunning = appProcess?.isRunning == true || appPID > 0
            if appRunning, try daemonHealthy() {
                usleep(500_000)
                return
            }
            usleep(50_000)
        }
        throw AutomationError.timeout("app did not become ready within 15s")
    }

    private func launchApp(homeDir: String, uiTestingOpenSettings: Bool) throws {
        if appProcess != nil {
            return
        }

        if daemonPort == 0 {
            daemonPort = (try? Self.pickEphemeralPort()) ?? 38272
        }
        if stateDir.isEmpty {
            stateDir = (homeDir as NSString).appendingPathComponent(".os-bar/agent-sessions")
        }
        try ensureDaemonRunning(homeDir: homeDir)

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = homeDir
        env["AGENT_SESSIONS_CLI"] = cliPath
        env["AGENT_SESSIONS_PORT"] = String(daemonPort)
        env["AGENT_SESSIONS_STATE_DIR"] = stateDir
        if captureAppOutput {
            env["AGENT_SESSIONS_NOTIFICATION_DEBUG_LOG"] = appLogPath
        }
        let cliDir = (cliPath as NSString).deletingLastPathComponent
        env["PATH"] = "\(cliDir):" + (env["PATH"] ?? "")

        if useAppBundle {
            let bundlePath = try Self.resolveNotificationAppBundle(projectRoot: projectRoot)
            try launchAppBundle(path: bundlePath, env: env)
            integrationsWindow = nil
            return
        }

        let appPath = try Self.buildApp(projectRoot: projectRoot)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        if uiTestingOpenSettings {
            process.arguments = ["-uiTestingOpenSettings"]
        }
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        appProcess = process
        appPID = process.processIdentifier
        integrationsWindow = nil
    }

    private func launchAppBundle(path: String, env: [String: String]) throws {
        if captureAppOutput {
            try? FileManager.default.createDirectory(
                atPath: (appLogPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: appLogPath, contents: nil)
        }

        // Quit any running menu-bar instance first. NSWorkspace env injection is unreliable
        // when an instance is already connected to the production daemon (port 38271).
        Self.quitExistingAgentSessionsApps()

        let executable = (path as NSString).appendingPathComponent("Contents/MacOS/os-bar-agent-sessions")
        guard FileManager.default.fileExists(atPath: executable) else {
            throw AutomationError.setup("bundle executable not found: \(executable)")
        }

        fputs("Launching bundle executable with AGENT_SESSIONS_PORT=\(env["AGENT_SESSIONS_PORT"] ?? "?") HOME=\(env["HOME"] ?? "?")\n", stderr)
        fflush(stderr)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        appProcess = process
        appPID = process.processIdentifier
    }

    func clickSettingsMenu() throws {
        guard appPID > 0 else {
            throw AutomationError.setup("app not launched")
        }

        if try clickSettingsViaIdentifiers() {
            return
        }

        let candidates = try menuBarExtraCandidates()
        guard !candidates.isEmpty else {
            throw AutomationError.setup("menu bar extra not found for app pid \(appPID)")
        }

        let tryLimit = min(candidates.count, 12)
        for extra in candidates.prefix(tryLimit) {
            _ = AXUIElementPerformAction(extra, kAXShowMenuAction as CFString)
            usleep(150_000)
            _ = AXUIElementPerformAction(extra, kAXPressAction as CFString)
            usleep(350_000)

            if try menuContainsAppSignature() {
                guard let settingsItem = try findSettingsMenuItem() else {
                    throw AutomationError.setup("Settings… menu item not found after opening menu")
                }
                guard AXUIElementPerformAction(settingsItem, kAXPressAction as CFString) == .success else {
                    throw AutomationError.setup("failed to press Settings… menu item")
                }
                try waitForIntegrationsWindow(timeout: 8)
                return
            }

            // Close menu before trying the next candidate.
            _ = AXUIElementPerformAction(extra, kAXPressAction as CFString)
            usleep(100_000)
        }

        throw AutomationError.setup("Settings… menu item not found for app pid \(appPID)")
    }

    func checkWindow() throws -> (visible: Bool, open: Bool) {
        guard appPID > 0 else {
            return (false, false)
        }
        guard let window = try findIntegrationsWindow() else {
            return (false, false)
        }
        let minimized = (try axBool(window, kAXMinimizedAttribute as CFString)) ?? false
        let hidden = (try axBool(window, kAXHiddenAttribute as CFString)) ?? false
        let open = true
        let visible = !minimized && !hidden
        return (visible, open)
    }

    func checkWindowFront() throws -> (main: Bool, frontmost: Bool) {
        guard appPID > 0 else {
            return (false, false)
        }
        let appElement = AXUIElementCreateApplication(appPID)
        let appFrontmost = (try axBool(appElement, kAXFrontmostAttribute as CFString)) ?? false
        let runningFrontmost = NSRunningApplication(processIdentifier: appPID)?.isActive ?? false

        guard let window = try findIntegrationsWindow() else {
            return (false, appFrontmost || runningFrontmost)
        }
        let windowMain = (try axBool(window, kAXMainAttribute as CFString)) ?? false
        let windowFocused = (try axBool(window, kAXFocusedAttribute as CFString)) ?? false
        return (windowMain || windowFocused, appFrontmost || runningFrontmost)
    }

    func obscureWindow() throws {
        guard let window = try findIntegrationsWindow() else {
            throw AutomationError.windowNotFound
        }
        _ = AXUIElementPerformAction(window, "AXLower" as CFString)
        usleep(200_000)
    }

    private func ensureDaemonRunning(homeDir: String) throws {
        if try daemonHealthy() {
            if daemonPID == 0 {
                daemonPID = Self.findServePID(port: daemonPort, stateDir: stateDir)
            }
            return
        }
        try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["serve", "--port", String(daemonPort), "--state-dir", stateDir]
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = homeDir
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        daemonProcess = process
        daemonPID = process.processIdentifier

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try daemonHealthy() {
                return
            }
            usleep(50_000)
        }
        throw AutomationError.setup("daemon did not become healthy within 5s on port \(daemonPort)")
    }

    private func daemonHealthy() throws -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(daemonPort)/api/health") else {
            return false
        }
        var request = URLRequest(url: url, timeoutInterval: 0.5)
        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false
        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data,
                  let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  body["ok"] as? Bool == true
            else {
                return
            }
            healthy = true
        }.resume()
        _ = semaphore.wait(timeout: .now() + 1)
        return healthy
    }

    private func waitForIntegrationsWindow(timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            integrationsWindow = nil
            if try findIntegrationsWindow() != nil {
                usleep(200_000)
                return
            }
            usleep(100_000)
        }
        throw AutomationError.windowNotFound
    }

    private func integrationsReady() throws -> Bool {
        guard let window = try findIntegrationsWindow() else {
            return false
        }
        if try findElement(in: window, identifier: "integration-grok-status", role: nil, title: nil) != nil {
            return true
        }
        return try findElement(in: window, identifier: "integration-grok", role: nil, title: nil) != nil
    }

    func dumpLayout() throws -> AXNode {
        guard let window = try findIntegrationsWindow() else {
            throw AutomationError.windowNotFound
        }
        return try collectIntegrationLayout(from: window)
    }

    func click(identifier: String?, role: String?, title: String?) throws -> (ok: Bool, x: Double, y: Double) {
        guard let window = try findIntegrationsWindow() else {
            throw AutomationError.windowNotFound
        }
        guard let target = try findElement(in: window, identifier: identifier, role: role, title: title) else {
            return (false, 0, 0)
        }

        NSRunningApplication(processIdentifier: appPID)?.activate(options: [.activateIgnoringOtherApps])
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        usleep(100_000)

        var clickPoint = CGPoint.zero
        if let frame = try axFrame(target) {
            clickPoint = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
        }

        var clicked = false
        if AXUIElementPerformAction(target, kAXPressAction as CFString) == .success {
            clicked = true
        }
        if clickPoint != .zero {
            clickAtScreenPoint(clickPoint)
            clicked = true
        }

        guard clicked else {
            return (false, 0, 0)
        }

        if let identifier, identifier.hasSuffix("-install") {
            let statusID = String(identifier.dropLast("-install".count)) + "-status"
            try waitForStatusChange(statusID: statusID, fromTitle: "Missing", timeout: 8)
        }

        return (true, Double(clickPoint.x), Double(clickPoint.y))
    }

    private func waitForStatusChange(statusID: String, fromTitle: String, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let window = try findIntegrationsWindow(),
               let status = try findElement(in: window, identifier: statusID, role: nil, title: nil),
               let node = try? elementToNode(status),
               let title = node.title,
               title != fromTitle {
                return
            }
            usleep(100_000)
        }
        throw AutomationError.timeout("status \(statusID) did not change from \(fromTitle) within \(Int(timeout))s")
    }

    func applyWait(ms: Int?) {
        guard let ms, ms > 0 else { return }
        usleep(useconds_t(ms) * 1000)
    }

    func teardown() {
        if let process = appProcess {
            let pid = process.processIdentifier
            Self.killChildProcesses(of: pid)
            if process.isRunning {
                process.terminate()
                usleep(100_000)
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
                process.waitUntilExit()
            }
        } else if appPID > 0 {
            Self.killChildProcesses(of: appPID)
            Self.signalPID(appPID, sig: SIGTERM)
            usleep(100_000)
            Self.signalPID(appPID, sig: SIGKILL)
        }
        if let process = daemonProcess {
            let pid = process.processIdentifier
            if process.isRunning {
                process.terminate()
                usleep(50_000)
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
                process.waitUntilExit()
            }
            Self.killChildProcesses(of: pid)
        }
        if daemonPID > 0 {
            Self.signalPID(daemonPID, sig: SIGTERM)
            usleep(50_000)
            Self.signalPID(daemonPID, sig: SIGKILL)
        }
        Self.killServeProcesses(port: daemonPort, stateDir: stateDir)
        appProcess = nil
        daemonProcess = nil
        appPID = 0
        daemonPID = 0
        integrationsWindow = nil
        dumpCount = 0
        daemonPort = 0
        stateDir = ""
        useAppBundle = false
        captureAppOutput = false
        appLogPath = ""
    }

    var capturedAppLogPath: String { appLogPath }
    var configuredDaemonPort: Int { daemonPort }

    func fetchDaemonEventSnapshot() throws -> (count: Int, dirs: [String]) {
        guard daemonPort > 0 else {
            throw AutomationError.setup("daemon port not configured")
        }
        let url = URL(string: "http://127.0.0.1:\(daemonPort)/api/list")!
        var request = URLRequest(url: url, timeoutInterval: 2)
        let semaphore = DispatchSemaphore(value: 0)
        var statusCode = 0
        var body = ""
        var requestError: Error?
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                requestError = error
                return
            }
            if let http = response as? HTTPURLResponse {
                statusCode = http.statusCode
            }
            if let data, let text = String(data: data, encoding: .utf8) {
                body = text
            }
        }.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        if let requestError {
            throw AutomationError.setup("daemon list failed: \(requestError.localizedDescription)")
        }
        guard statusCode == 200 else {
            throw AutomationError.setup("daemon list HTTP \(statusCode): \(body)")
        }
        guard let data = body.data(using: .utf8),
              let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            throw AutomationError.setup("daemon list decode failed: \(body)")
        }
        let dirs = events.compactMap { $0["dir"] as? String }
        return (events.count, dirs)
    }

    func waitForAppNotificationPosted(timeout: TimeInterval) -> Bool {
        let markers = ["notification_posted", "handle_refresh_notify_"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let lines = readCapturedAppLog()
            if lines.contains(where: { line in
                markers.contains(where: { line.contains($0) })
            }) {
                return true
            }
            usleep(500_000)
        }
        return false
    }

    func postSessionNotify(dir: String) throws {
        guard daemonPort > 0 else {
            throw AutomationError.setup("daemon port not configured")
        }
        let url = URL(string: "http://127.0.0.1:\(daemonPort)/api/notify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "dir": dir,
            "source": "notify",
        ])

        let semaphore = DispatchSemaphore(value: 0)
        var statusCode = 0
        var responseBody = ""
        var requestError: Error?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                requestError = error
                return
            }
            if let http = response as? HTTPURLResponse {
                statusCode = http.statusCode
            }
            if let data, let body = String(data: data, encoding: .utf8) {
                responseBody = body
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 10)

        if let requestError {
            throw AutomationError.setup("post notify failed: \(requestError.localizedDescription)")
        }
        guard statusCode == 200 else {
            throw AutomationError.setup("post notify HTTP \(statusCode): \(responseBody)")
        }
    }

    func clickSessionNotification(title: String, timeout: TimeInterval) throws -> (clicked: Bool, x: Double, y: Double) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let (element, point) = try findNotificationClickTarget(title: title) {
                var clicked = false
                if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                    clicked = true
                }
                if point != .zero {
                    clickAtGlobalScreenPoint(point)
                    clicked = true
                }
                if clicked {
                    return (true, Double(point.x), Double(point.y))
                }
            }
            usleep(250_000)
        }
        return (false, 0, 0)
    }

    func captureNotificationClickLogs(seconds: Int) throws -> [String] {
        let window = min(max(seconds, 5), 30)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        proc.arguments = [
            "show",
            "--last", "\(window)s",
            "--style", "compact",
            "--predicate", "eventMessage CONTAINS \"[NotificationClick]\" OR eventMessage CONTAINS \"vscode_activation\"",
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()

        let deadline = Date().addingTimeInterval(15)
        while proc.isRunning, Date() < deadline {
            usleep(100_000)
        }
        if proc.isRunning {
            proc.terminate()
            usleep(50_000)
            if proc.isRunning {
                kill(proc.processIdentifier, SIGKILL)
            }
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func waitForNotificationAuthStatus(timeout: TimeInterval) -> (authorized: Bool, status: String, bundleID: String) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let lines = readCapturedAppLog()
            let auth = parseNotificationAuth(from: lines)
            if !auth.status.isEmpty {
                return auth
            }
            usleep(500_000)
        }
        return parseNotificationAuth(from: readCapturedAppLog())
    }

    func parseNotificationAuth(from lines: [String]) -> (authorized: Bool, status: String, bundleID: String) {
        var status = ""
        var bundleID = ""
        for line in lines.reversed() {
            if status.isEmpty, line.contains("notification_diagnostics"), line.contains("authorization=") {
                if let range = line.range(of: "authorization=") {
                    let tail = line[range.upperBound...]
                    status = tail.split(separator: " ").first.map(String.init) ?? ""
                }
            }
            if bundleID.isEmpty, line.contains("bundle_id=") {
                if let range = line.range(of: "bundle_id=") {
                    let tail = line[range.upperBound...]
                    bundleID = tail.split(separator: " ").first.map(String.init) ?? ""
                }
            }
        }
        let authorized = status == "authorized" || status == "provisional" || status == "ephemeral"
        return (authorized, status, bundleID)
    }

    func readCapturedAppLog() -> [String] {
        guard !appLogPath.isEmpty,
              let text = try? String(contentsOfFile: appLogPath, encoding: .utf8)
        else {
            return []
        }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func notificationClickCount(in lines: [String]) -> Int {
        lines.filter { $0.contains("delegate_did_receive") }.count
    }

    func waitForManualNotificationClick(
        notifyDir: String,
        title: String,
        timeout: TimeInterval,
        phase: Int = 1,
        minimumClicks: Int = 1
    ) -> Bool {
        fputs("\n", stderr)
        fputs("=== NOTIFICATION READY — CLICK IT NOW (phase \(phase)) ===\n", stderr)
        fputs("Title: \(title)\n", stderr)
        fputs("Dir:   \(notifyDir)\n", stderr)
        fputs("Waiting up to \(Int(timeout))s for click #\(minimumClicks)...\n", stderr)
        fputs("============================================================\n\n", stderr)
        fflush(stderr)

        let deadline = Date().addingTimeInterval(timeout)
        var lastPrinted = 0
        while Date() < deadline {
            let lines = readCapturedAppLog()
            if notificationClickCount(in: lines) >= minimumClicks {
                fputs("Detected notification click #\(minimumClicks) in app log.\n", stderr)
                fflush(stderr)
                return true
            }
            let remaining = Int(deadline.timeIntervalSinceNow)
            if remaining != lastPrinted, remaining % 10 == 0 {
                fputs("... still waiting (\(remaining)s left)\n", stderr)
                fflush(stderr)
                lastPrinted = remaining
            }
            usleep(500_000)
        }
        fputs("Timed out waiting for manual notification click (phase \(phase)).\n", stderr)
        fflush(stderr)
        return false
    }

    func prepareNotificationTest(
        homeDir: String,
        workDir: String,
        stateDir: String?,
        resp: inout Response
    ) throws {
        configureNotificationUITest(homeDir: homeDir, stateDir: stateDir, captureAppOutput: true)
        try configure(homeDir: homeDir, workDir: workDir, stateDir: stateDir)
        try launchApp(homeDir: homeDir)
        resp.daemon_port = configuredDaemonPort
        usleep(2_000_000)

        let auth = waitForNotificationAuthStatus(timeout: 15)
        resp.notification_auth_status = auth.status
        resp.notification_bundle_id = auth.bundleID
        resp.notification_authorized = auth.authorized
        resp.app_log_path = capturedAppLogPath
        resp.app_log_lines = readCapturedAppLog()
        if auth.status.isEmpty {
            throw AutomationError.setup(
                "no notification_diagnostics in app log (app_log_path=\(capturedAppLogPath)); run ./script/install-debug.sh --no-open"
            )
        }
        if !auth.authorized {
            throw AutomationError.setup(
                "notification not authorized (status=\(auth.status), bundle_id=\(auth.bundleID)); enable Notifications in System Settings"
            )
        }
    }

    func postNotifyAndWaitForBanner(
        dir: String,
        phase: Int,
        resp: inout Response
    ) throws {
        try postSessionNotify(dir: dir)
        resp.notification_posted = true

        let snapshot = try fetchDaemonEventSnapshot()
        resp.daemon_event_count = snapshot.count
        resp.daemon_has_notify_event = snapshot.dirs.contains(dir)
        if !resp.daemon_has_notify_event {
            throw AutomationError.setup(
                "daemon accepted POST but event not in /api/list (port=\(resp.daemon_port), dirs=\(snapshot.dirs))"
            )
        }

        let appPosted = waitForAppNotificationPosted(timeout: 12)
        resp.app_saw_notification_posted = appPosted
        resp.app_log_lines = readCapturedAppLog()
        if !appPosted {
            throw AutomationError.setup(
                "app never posted macOS notification after daemon event (phase \(phase)); app_log_path=\(capturedAppLogPath)"
            )
        }

        fputs("Phase \(phase): posted /api/notify for dir=\(dir). Click the banner when it appears.\n", stderr)
        fflush(stderr)
    }

    private func findNotificationClickTarget(title: String) throws -> (AXUIElement, CGPoint)? {
        let markers = [title, "Agent session finished"]
        let bundleIDs = [
            "com.apple.notificationcenterui",
            "com.apple.UserNotificationCenter",
            "com.apple.systemuiserver",
        ]

        var roots: [AXUIElement] = [AXUIElementCreateSystemWide()]
        for bundleID in bundleIDs {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                roots.append(AXUIElementCreateApplication(app.processIdentifier))
            }
        }

        for root in roots {
            if let match = try findClickableElement(containingAny: markers, in: root, maxVisited: 400) {
                return match
            }
        }
        return nil
    }

    private func findClickableElement(
        containingAny markers: [String],
        in root: AXUIElement,
        maxVisited: Int
    ) throws -> (AXUIElement, CGPoint)? {
        var stack = [root]
        var visited = 0
        let pressableRoles: Set<String> = [
            "AXButton", "AXGroup", "AXStaticText", "AXCell", "AXRow", "AXList",
            "AXWindow", "AXSheet", "AXPopover",
        ]

        while !stack.isEmpty, visited < maxVisited {
            let element = stack.removeLast()
            visited += 1

            let role = try axRole(element)
            let title = try axString(element, kAXTitleAttribute as CFString) ?? ""
            let value = try axString(element, kAXValueAttribute as CFString) ?? ""
            let description = try axString(element, kAXDescriptionAttribute as CFString) ?? ""
            let combined = "\(title) \(value) \(description)"

            if markers.contains(where: { combined.localizedCaseInsensitiveContains($0) }),
               pressableRoles.contains(role)
            {
                var point = CGPoint.zero
                if let frame = try axFrame(element) {
                    point = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
                }
                return (element, point)
            }

            if let children = try axChildren(element) {
                stack.append(contentsOf: children.reversed())
            }
        }
        return nil
    }

    private func clickAtGlobalScreenPoint(_ point: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        else {
            return
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    func recordDump(_ node: AXNode, into response: inout Response) {
        dumpCount += 1
        if dumpCount == 1 {
            response.layout_before = node
        }
        response.layout = node
        response.layout_after = node
    }

    private func findIntegrationsWindow() throws -> AXUIElement? {
        if let cached = integrationsWindow {
            return cached
        }
        guard appPID > 0 else { return nil }
        let app = AXUIElementCreateApplication(appPID)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        if err == .apiDisabled {
            throw AutomationError.apiDisabled
        }
        guard err == .success, let windows = value as? [AXUIElement] else {
            return nil
        }

        for window in windows {
            if let title = try axString(window, kAXTitleAttribute as CFString), title == "Integrations" {
                integrationsWindow = window
                return window
            }
            if try findElement(in: window, identifier: "integrations-window", role: nil, title: nil) != nil {
                integrationsWindow = window
                return window
            }
            if try findElement(in: window, identifier: "integration-grok", role: nil, title: nil) != nil {
                integrationsWindow = window
                return window
            }
        }
        return nil
    }

    private func collectIntegrationLayout(from window: AXUIElement) throws -> AXNode {
        let targets = [
            "integrations-window",
            "integration-grok", "integration-grok-status", "integration-grok-install",
            "integration-opencode", "integration-opencode-status", "integration-opencode-install",
            "integration-pi", "integration-pi-status", "integration-pi-install",
            "integration-codex", "integration-codex-status", "integration-codex-install",
        ]
        var nodes: [AXNode] = []
        for target in targets {
            if let element = try findElement(in: window, identifier: target, role: nil, title: nil) {
                nodes.append(try elementToNode(element))
            }
        }
        return AXNode(
            role: "AXWindow",
            title: "Integrations",
            identifier: "integrations-window",
            value: nil,
            frame: nil,
            children: nodes.isEmpty ? nil : nodes
        )
    }

    private func elementToNode(_ element: AXUIElement) throws -> AXNode {
        let role = try axRole(element)
        var title = try axString(element, kAXTitleAttribute as CFString)
        let identifier = try axString(element, kAXIdentifierAttribute as CFString)
        let value = try axString(element, kAXValueAttribute as CFString)
        if title == nil, let description = try axString(element, kAXDescriptionAttribute as CFString) {
            title = description
        }
        if title == nil, role == "AXStaticText", let value {
            title = value
        }
        if title == nil, let value {
            title = value
        }
        return AXNode(
            role: role,
            title: title,
            identifier: identifier,
            value: value,
            frame: try axFrame(element),
            children: nil
        )
    }

    private func findElement(
        in root: AXUIElement,
        identifier: String?,
        role: String?,
        title: String?
    ) throws -> AXUIElement? {
        var stack = [root]
        var visited = 0
        while !stack.isEmpty, visited < 512 {
            let element = stack.removeLast()
            visited += 1
            let elementRole = try axRole(element)
            let elementTitle = try axString(element, kAXTitleAttribute as CFString)
            let elementIdentifier = try axString(element, kAXIdentifierAttribute as CFString)

            let roleMatch = role == nil || role == elementRole
            let titleMatch = title == nil || title == elementTitle
            let idMatch = identifier == nil || identifier == elementIdentifier
            if roleMatch && titleMatch && idMatch && (identifier != nil || role != nil || title != nil) {
                return element
            }

            if let children = try axChildren(element) {
                stack.append(contentsOf: children.reversed())
            }
        }
        return nil
    }

    private func serializeElement(_ element: AXUIElement, depth: Int = 0) throws -> AXNode {
        let role = try axRole(element)
        var title = try axString(element, kAXTitleAttribute as CFString)
        let identifier = try axString(element, kAXIdentifierAttribute as CFString)
        let value = try axString(element, kAXValueAttribute as CFString)
        if title == nil, role == "AXStaticText", let value {
            title = value
        }
        let frame = try axFrame(element)

        var children: [AXNode]?
        if depth < 12 {
            let childrenAX = try axChildren(element) ?? []
            if !childrenAX.isEmpty {
                children = try childrenAX.prefix(64).map { try serializeElement($0, depth: depth + 1) }
            }
        }

        return AXNode(
            role: role,
            title: title,
            identifier: identifier,
            value: value,
            frame: frame,
            children: children
        )
    }

    private func axRole(_ element: AXUIElement) throws -> String {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        if err == .apiDisabled { throw AutomationError.apiDisabled }
        guard err == .success, let role = value as? String else { return "AXUnknown" }
        return role
    }

    private func axString(_ element: AXUIElement, _ attribute: CFString) throws -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        if err == .apiDisabled { throw AutomationError.apiDisabled }
        guard err == .success else { return nil }
        if let str = value as? String, !str.isEmpty { return str }
        return nil
    }

    private func axBool(_ element: AXUIElement, _ attribute: CFString) throws -> Bool? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        if err == .apiDisabled { throw AutomationError.apiDisabled }
        guard err == .success else { return nil }
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }

    private func axPID(_ element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return 0 }
        return pid
    }

    private func pressElement(_ element: AXUIElement) throws -> Bool {
        NSRunningApplication(processIdentifier: appPID)?.activate(options: [.activateIgnoringOtherApps])
        var clicked = false
        if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            clicked = true
        }
        if let frame = try axFrame(element) {
            let point = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
            clickAtScreenPoint(point)
            clicked = true
        }
        return clicked
    }

    private func clickSettingsViaIdentifiers() throws -> Bool {
        let app = AXUIElementCreateApplication(appPID)
        var extra = try findElement(in: app, identifier: "menu-bar-extra", role: nil, title: nil)
        if extra == nil {
            extra = try menuBarExtraCandidates().first
        }
        guard let extra else {
            return false
        }

        _ = AXUIElementPerformAction(extra, kAXPressAction as CFString)
        usleep(500_000)

        guard let settings = try findSettingsMenuItem() else {
            _ = AXUIElementPerformAction(extra, kAXPressAction as CFString)
            return false
        }

        guard AXUIElementPerformAction(settings, kAXPressAction as CFString) == .success else {
            return false
        }
        try waitForIntegrationsWindow(timeout: 8)
        return true
    }

    private func menuBarExtraCandidates() throws -> [AXUIElement] {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let candidates = try collectMenuBarExtraCandidates()
            if !candidates.isEmpty {
                return candidates
            }
            usleep(250_000)
        }
        return try collectMenuBarExtraCandidates()
    }

    private func collectMenuBarExtraCandidates() throws -> [AXUIElement] {
        let system = AXUIElementCreateSystemWide()
        let app = AXUIElementCreateApplication(appPID)
        var candidates: [AXUIElement] = []
        var seen = Set<ObjectIdentifier>()

        func appendCandidate(_ element: AXUIElement) {
            let key = ObjectIdentifier(element)
            guard !seen.contains(key) else { return }
            seen.insert(key)
            candidates.append(element)
        }

        func consider(_ element: AXUIElement) throws {
            let role = try axRole(element)
            let pid = axPID(element)
            let title = try axString(element, kAXTitleAttribute as CFString) ?? ""
            let description = try axString(element, kAXDescriptionAttribute as CFString) ?? ""
            let identifier = try axString(element, kAXIdentifierAttribute as CFString) ?? ""
            let pressableRoles: Set<String> = [
                "AXMenuBarItem", "AXMenuButton", "AXButton", "AXStatusItem", "AXMenuExtra",
            ]
            let bellish = title.localizedCaseInsensitiveContains("bell")
                || description.localizedCaseInsensitiveContains("bell")
            if identifier == "menu-bar-extra" {
                appendCandidate(element)
                return
            }
            if pressableRoles.contains(role), pid == appPID || pid == 0 || bellish {
                appendCandidate(element)
            }
        }

        if let menubar = try findElement(in: system, identifier: nil, role: "AXMenuBar", title: nil) {
            var stack = [menubar]
            var visited = 0
            while !stack.isEmpty, visited < 256 {
                let element = stack.removeLast()
                visited += 1
                try consider(element)
                if let children = try axChildren(element) {
                    stack.append(contentsOf: children.reversed())
                }
            }
        }

        var stack = [app]
        var visited = 0
        while !stack.isEmpty, visited < 256 {
            let element = stack.removeLast()
            visited += 1
            try consider(element)
            if let children = try axChildren(element) {
                stack.append(contentsOf: children.reversed())
            }
        }

        return candidates
    }

    private func menuContainsAppSignature() throws -> Bool {
        let root = AXUIElementCreateSystemWide()
        let markers = ["Settings…", "Settings...", "Settings", "Quit", "Auto Start", "No sessions"]
        var hits = 0
        for marker in markers {
            if try findMenuItem(containing: marker, in: root) != nil {
                hits += 1
            }
        }
        return hits >= 2
    }

    private func findOpenMenu(near element: AXUIElement) throws -> AXUIElement? {
        var stack = [element]
        var visited = 0
        while !stack.isEmpty, visited < 128 {
            let current = stack.removeLast()
            visited += 1
            let role = try axRole(current)
            if role == "AXMenu" {
                return current
            }
            if let children = try axChildren(current) {
                stack.append(contentsOf: children.reversed())
            }
        }

        let system = AXUIElementCreateSystemWide()
        if let children = try axChildren(system) {
            for child in children {
                if try axRole(child) == "AXMenu" {
                    return child
                }
            }
        }
        return nil
    }

    private func findSettingsMenuItem() throws -> AXUIElement? {
        let app = AXUIElementCreateApplication(appPID)
        if let extra = try findElement(in: app, identifier: "menu-bar-extra", role: nil, title: nil) {
            for exactTitle in ["Settings…", "Settings..."] {
                if let item = try findMenuItem(exactTitle: exactTitle, in: extra) {
                    return item
                }
            }
        }
        if let item = try findElement(in: app, identifier: "settings-menu-button", role: nil, title: nil) {
            return item
        }
        for exactTitle in ["Settings…", "Settings..."] {
            if let item = try findMenuItem(exactTitle: exactTitle, in: app) {
                return item
            }
        }
        return nil
    }

    private func findMenuItem(exactTitle: String, in root: AXUIElement) throws -> AXUIElement? {
        var stack = [root]
        var visited = 0
        while !stack.isEmpty, visited < 256 {
            let element = stack.removeLast()
            visited += 1
            let role = try axRole(element)
            let title = try axString(element, kAXTitleAttribute as CFString) ?? ""
            if role == "AXMenuItem", title == exactTitle {
                return element
            }
            if let children = try axChildren(element) {
                stack.append(contentsOf: children.reversed())
            }
        }
        return nil
    }

    private func findMenuItem(containing needle: String, in root: AXUIElement, ownedByApp: Bool = false) throws -> AXUIElement? {
        var stack = [root]
        var visited = 0
        while !stack.isEmpty, visited < 768 {
            let element = stack.removeLast()
            visited += 1
            if ownedByApp {
                let pid = axPID(element)
                if pid != 0, pid != appPID {
                    if let children = try axChildren(element) {
                        stack.append(contentsOf: children.reversed())
                    }
                    continue
                }
            }
            let role = try axRole(element)
            let title = try axString(element, kAXTitleAttribute as CFString) ?? ""
            let description = try axString(element, kAXDescriptionAttribute as CFString) ?? ""
            let identifier = try axString(element, kAXIdentifierAttribute as CFString) ?? ""
            if ["AXMenuItem", "AXButton"].contains(role),
               identifier == "settings-menu-button"
               || title.localizedCaseInsensitiveContains(needle)
               || description.localizedCaseInsensitiveContains(needle) {
                return element
            }
            if let children = try axChildren(element) {
                stack.append(contentsOf: children.reversed())
            }
        }
        return nil
    }

    private func axChildren(_ element: AXUIElement) throws -> [AXUIElement]? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        if err == .apiDisabled { throw AutomationError.apiDisabled }
        guard err == .success, let children = value as? [AXUIElement] else { return nil }
        return children
    }

    private func axFrame(_ element: AXUIElement) throws -> AXFrame? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let posErr = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        let sizeErr = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        if posErr == .apiDisabled || sizeErr == .apiDisabled { throw AutomationError.apiDisabled }
        guard posErr == .success, sizeErr == .success else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        if let posAX = posValue {
            AXValueGetValue(posAX as! AXValue, .cgPoint, &point)
        }
        if let sizeAX = sizeValue {
            AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)
        }
        return AXFrame(x: Double(point.x), y: Double(point.y), w: Double(size.width), h: Double(size.height))
    }

    private func clickAtScreenPoint(_ point: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        else {
            return
        }
        if appPID > 0 {
            down.postToPid(appPID)
            up.postToPid(appPID)
        } else {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    static func findProjectRoot() throws -> String {
        var dir = FileManager.default.currentDirectoryPath
        let fm = FileManager.default
        while true {
            let package = (dir as NSString).appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: package) {
                return dir
            }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir {
                break
            }
            dir = parent
        }
        throw AutomationError.setup("could not find Package.swift from cwd")
    }

    private static func buildCLI(projectRoot: String) throws -> String {
        let out = (projectRoot as NSString).appendingPathComponent(".build/agent-sessions")
        if FileManager.default.fileExists(atPath: out) {
            return out
        }
        let pkg = (projectRoot as NSString).appendingPathComponent("go-pkgs/cmd/agent-sessions")
        let build = Process()
        build.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        build.arguments = ["go", "build", "-o", out, "."]
        build.currentDirectoryURL = URL(fileURLWithPath: pkg)
        let pipe = Pipe()
        build.standardOutput = pipe
        build.standardError = pipe
        try build.run()
        build.waitUntilExit()
        if build.terminationStatus != 0 {
            let outStr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AutomationError.setup("go build agent-sessions failed: \(outStr)")
        }
        return out
    }

    private static func appBinaryPath(projectRoot: String) throws -> String {
        let candidates = [
            (projectRoot as NSString).appendingPathComponent(".build/debug/os-bar-agent-sessions"),
            (projectRoot as NSString).appendingPathComponent(".build/arm64-apple-macosx/debug/os-bar-agent-sessions"),
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }

        let buildRoot = (projectRoot as NSString).appendingPathComponent(".build")
        if let enumerator = FileManager.default.enumerator(atPath: buildRoot) {
            while let item = enumerator.nextObject() as? String {
                if item.hasSuffix("/debug/os-bar-agent-sessions") || item == "debug/os-bar-agent-sessions" {
                    let path = (buildRoot as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue {
                        return path
                    }
                }
            }
        }
        throw AutomationError.setup("app binary not found under \(buildRoot)")
    }

    private static func signalPID(_ pid: pid_t, sig: Int32) {
        guard pid > 0 else { return }
        if kill(pid, sig) == 0 {
            return
        }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        if sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0,
           info.kp_proc.p_pid == pid
        {
            _ = kill(pid, sig)
        }
    }

    private static func pidsMatching(pattern: String) -> [pid_t] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-f", pattern]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var pids: [pid_t] = []
        for line in text.split(separator: "\n") {
            if let pid = Int32(line.trimmingCharacters(in: .whitespaces)), pid > 0 {
                pids.append(pid)
            }
        }
        return pids
    }

    private static func findServePID(port: Int, stateDir: String) -> pid_t {
        for pattern in serveMatchPatterns(port: port, stateDir: stateDir) {
            if let pid = pidsMatching(pattern: pattern).first {
                return pid
            }
        }
        return 0
    }

    private static func serveMatchPatterns(port: Int, stateDir: String) -> [String] {
        var patterns: [String] = []
        if port > 0 {
            patterns.append("agent-sessions serve --port \(port)")
        }
        if !stateDir.isEmpty {
            patterns.append("agent-sessions serve.*--state-dir \(NSRegularExpression.escapedPattern(for: stateDir))")
        }
        return patterns
    }

    private static func killServeProcesses(port: Int, stateDir: String) {
        var pids = Set<pid_t>()
        for pattern in serveMatchPatterns(port: port, stateDir: stateDir) {
            for pid in pidsMatching(pattern: pattern) {
                pids.insert(pid)
            }
        }
        for pid in pids {
            signalPID(pid, sig: SIGTERM)
        }
        usleep(100_000)
        for pid in pids {
            signalPID(pid, sig: SIGKILL)
        }
    }

    private static let debugInstalledApp = "/Applications/os-bar-agent-sessions-debug.app"

    private static func quitExistingAgentSessionsApps() {
        let patterns = [
            "os-bar-agent-sessions-debug.app/Contents/MacOS/os-bar-agent-sessions",
        ]
        var pids = Set<pid_t>()
        for pattern in patterns {
            for pid in pidsMatching(pattern: pattern) {
                pids.insert(pid)
            }
        }
        for pid in pids {
            signalPID(pid, sig: SIGTERM)
        }
        usleep(300_000)
        for pid in pids {
            signalPID(pid, sig: SIGKILL)
        }
        usleep(200_000)
    }

    private static func killChildProcesses(of parentPID: pid_t) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-P", String(parentPID)]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            if let child = Int32(line.trimmingCharacters(in: .whitespaces)) {
                kill(child, SIGKILL)
            }
        }
    }

    private static func pickEphemeralPort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw AutomationError.setup("socket() failed")
        }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw AutomationError.setup("bind() failed for ephemeral port")
        }

        var bound = sockaddr_in()
        var boundLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &bound) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &boundLen)
            }
        }
        guard nameResult == 0 else {
            throw AutomationError.setup("getsockname() failed")
        }
        return Int(UInt16(bigEndian: bound.sin_port))
    }

    private static func resolveNotificationAppBundle(projectRoot: String) throws -> String {
        _ = projectRoot
        if FileManager.default.fileExists(atPath: debugInstalledApp) {
            fputs("Using debug app: \(debugInstalledApp) (bundle: com.os-bar.agent-sessions.debug)\n", stderr)
            fflush(stderr)
            return debugInstalledApp
        }
        throw AutomationError.setup(
            "debug app not installed at \(debugInstalledApp); run: ./script/install-debug.sh --no-open"
        )
    }

    private static func buildApp(projectRoot: String) throws -> String {
        if let path = try? appBinaryPath(projectRoot: projectRoot) {
            return path
        }

        let build = Process()
        build.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        build.arguments = ["swift", "build", "-c", "debug"]
        build.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
        let pipe = Pipe()
        build.standardOutput = pipe
        build.standardError = pipe
        try build.run()
        build.waitUntilExit()
        if build.terminationStatus != 0 {
            let outStr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AutomationError.setup("swift build failed: \(outStr)")
        }
        return try appBinaryPath(projectRoot: projectRoot)
    }

    enum AutomationError: LocalizedError {
        case apiDisabled
        case windowNotFound
        case timeout(String)
        case setup(String)

        var errorDescription: String? {
            switch self {
            case .apiDisabled:
                return "kAXErrorAPIDisabled (-25211)"
            case .windowNotFound:
                return "Integrations window not found"
            case .timeout(let msg):
                return msg
            case .setup(let msg):
                return msg
            }
        }
    }
}

enum HumanAssistedDialog {
    static let installHint = "go install github.com/xhd2015/agent-pro/agents/debug-with-user@latest"
    private static let customizeCancelLabel = "Cancel"

    enum Answer {
        case affirmed
        case denied
        case custom(report: String)
        case dismissed
    }

    struct AskOutcome {
        var available: Bool
        var dismissed: Bool
        var via: String
        var answer: String
        var affirmed: Bool
    }

    static func isAvailable() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["sh", "-c", "command -v debug-with-user"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return proc.terminationStatus == 0 && !path.isEmpty
    }

    private static func runAsk(
        title: String,
        message: String,
        options: [String],
        affirm: String,
        cancel: String
    ) -> AskOutcome? {
        guard isAvailable() else {
            fputs(">>> [HumanAssisted] debug-with-user not installed; run: \(installHint)\n", stderr)
            fflush(stderr)
            return nil
        }

        fputs(">>> [HumanAssisted] Showing dialog via debug-with-user: \(title)\n", stderr)
        fflush(stderr)

        // --cancel applies only to the Customize text-entry step; keep a neutral label.
        var args = ["ask", "--title", title, "--message", message, "--affirm", affirm, "--cancel", customizeCancelLabel]
        for option in options {
            args.append(contentsOf: ["--option", option])
        }
        _ = cancel // preset labels are --option only; alert has no cancel-button mapping

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["debug-with-user"] + args
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            fputs(">>> [HumanAssisted] debug-with-user failed: \(error)\n", stderr)
            fflush(stderr)
            return nil
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""

        if proc.terminationStatus == 1 {
            fputs(">>> [HumanAssisted] dialog dismissed: \(stderrText)\n", stderr)
            fflush(stderr)
            return AskOutcome(available: true, dismissed: true, via: "dismissed", answer: "", affirmed: false)
        }
        guard proc.terminationStatus == 0 else {
            fputs(">>> [HumanAssisted] debug-with-user error (status=\(proc.terminationStatus)): \(stderrText)\n", stderr)
            fflush(stderr)
            return nil
        }

        guard let jsonData = stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let via = obj["via"] as? String,
              let answer = obj["answer"] as? String
        else {
            fputs(">>> [HumanAssisted] invalid JSON stdout: \(stdout)\n", stderr)
            fflush(stderr)
            return nil
        }

        let affirmed = (obj["affirmed"] as? Bool) ?? false
        fputs(">>> [HumanAssisted] via=\(via) answer=\(answer) affirmed=\(affirmed)\n", stderr)
        fflush(stderr)
        return AskOutcome(available: true, dismissed: false, via: via, answer: answer, affirmed: affirmed)
    }

    private static func interpret(_ outcome: AskOutcome?) -> Answer? {
        guard let outcome else {
            return nil
        }
        if outcome.dismissed {
            return .dismissed
        }
        if outcome.via == "free_text" {
            return .custom(report: outcome.answer)
        }
        if outcome.via == "button" {
            return outcome.affirmed ? .affirmed : .denied
        }
        return .denied
    }

    static func askConfirm(
        title: String,
        message: String,
        yesButton: String,
        noButton: String
    ) -> Answer? {
        interpret(runAsk(
            title: title,
            message: message,
            options: [noButton, yesButton],
            affirm: yesButton,
            cancel: noButton
        ))
    }

    static func askProceed(
        title: String,
        message: String,
        proceedButton: String = "OK — ready",
        cancelButton: String = "Cancel test"
    ) -> Answer? {
        interpret(runAsk(
            title: title,
            message: message,
            options: [cancelButton, proceedButton],
            affirm: proceedButton,
            cancel: cancelButton
        ))
    }

    static func confirmYesNo(
        title: String,
        message: String,
        yesButton: String,
        noButton: String
    ) -> Bool {
        guard case .affirmed = askConfirm(title: title, message: message, yesButton: yesButton, noButton: noButton) else {
            return false
        }
        return true
    }

    static func proceedOrCancel(
        title: String,
        message: String,
        proceedButton: String = "OK — ready",
        cancelButton: String = "Cancel test"
    ) -> Bool {
        guard case .affirmed = askProceed(
            title: title,
            message: message,
            proceedButton: proceedButton,
            cancelButton: cancelButton
        ) else {
            return false
        }
        return true
    }
}

func withAutomationLock<T>(projectRoot: String, _ body: () throws -> T) throws -> T {
    let lockDir = (projectRoot as NSString).appendingPathComponent(".build")
    try? FileManager.default.createDirectory(atPath: lockDir, withIntermediateDirectories: true)
    let lockPath = (lockDir as NSString).appendingPathComponent("ui-automation.lock")
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
    if fd >= 0 {
        let deadline = Date().addingTimeInterval(60)
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            if Date() >= deadline {
                close(fd)
                throw UIAutomationSession.AutomationError.timeout("ui-automation lock timeout after 60s")
            }
            usleep(100_000)
        }
    }
    defer {
        if fd >= 0 {
            flock(fd, LOCK_UN)
            close(fd)
        }
    }
    return try body()
}

func runHelper() -> Never {
    guard let input = readLine() else {
        fputs("{\"error\":\"no input provided\"}\n", stderr)
        exit(1)
    }

    guard let jsonData = input.data(using: .utf8),
          var request = try? JSONDecoder().decode(Request.self, from: jsonData)
    else {
        fputs("{\"error\":\"invalid JSON input\"}\n", stderr)
        exit(1)
    }

    var response = Response()
    let session = UIAutomationSession.shared

    let homeDir = request.home_dir ?? ""
    let workDir = request.work_dir ?? ""
    response.home_dir = homeDir
    response.work_dir = workDir

    func handle(_ req: Request, _ resp: inout Response) {
        switch req.action {
        case "open_settings":
            do {
                session.applyWait(ms: req.wait_ms)
                try session.configure(homeDir: homeDir, workDir: workDir)
                try session.openSettings(homeDir: homeDir)
                resp.window_open = true
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "open_settings failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "dump_layout":
            do {
                session.applyWait(ms: req.wait_ms)
                let layout = try session.dumpLayout()
                session.recordDump(layout, into: &resp)
                resp.window_open = true
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "dump_layout failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "click":
            do {
                session.applyWait(ms: req.wait_ms)
                let result = try session.click(
                    identifier: req.identifier,
                    role: req.role,
                    title: req.title
                )
                resp.click_ok = result.ok
                resp.click_x = result.x
                resp.click_y = result.y
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "click failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "launch_app":
            do {
                session.applyWait(ms: req.wait_ms)
                try session.configure(homeDir: homeDir, workDir: workDir)
                try session.launchApp(homeDir: homeDir)
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "launch_app failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "click_settings_menu":
            do {
                session.applyWait(ms: req.wait_ms)
                try session.clickSettingsMenu()
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "click_settings_menu failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "check_window":
            do {
                session.applyWait(ms: req.wait_ms)
                let state = try session.checkWindow()
                resp.window_visible = state.visible
                resp.window_open = state.open
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "check_window failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "check_window_front":
            do {
                session.applyWait(ms: req.wait_ms)
                let state = try session.checkWindowFront()
                resp.window_main = state.main
                resp.app_frontmost = state.frontmost
                let windowState = try session.checkWindow()
                resp.window_open = windowState.open
                resp.window_visible = windowState.visible
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "check_window_front failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "obscure_window":
            do {
                session.applyWait(ms: req.wait_ms)
                try session.obscureWindow()
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "obscure_window failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "teardown":
            session.teardown()

        case "notification_post_manual_click":
            do {
                let notifyDir = req.notify_dir ?? workDir
                let title = req.notification_title ?? "Agent session finished"
                let logSeconds = req.log_capture_seconds ?? 20
                let waitSeconds = req.manual_click_wait_seconds ?? 120

                try session.prepareNotificationTest(
                    homeDir: homeDir,
                    workDir: workDir,
                    stateDir: request.state_dir,
                    resp: &resp
                )
                try session.postNotifyAndWaitForBanner(dir: notifyDir, phase: 1, resp: &resp)

                let clicked = session.waitForManualNotificationClick(
                    notifyDir: notifyDir,
                    title: title,
                    timeout: TimeInterval(waitSeconds)
                )
                resp.notification_clicked = clicked
                resp.click_ok = clicked
                usleep(2_000_000)

                resp.app_log_path = session.capturedAppLogPath
                resp.app_log_lines = session.readCapturedAppLog()
                resp.log_lines = try session.captureNotificationClickLogs(seconds: logSeconds)
                resp.notification_click_log_lines = resp.log_lines.filter {
                    $0.contains("[NotificationClick]")
                }
                resp.vscode_log_lines = (resp.log_lines + resp.app_log_lines).filter {
                    let lower = $0.lowercased()
                    return lower.contains("vscode") || lower.contains("code_process")
                }
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "notification_post_manual_click failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "notification_window_focus_manual":
            do {
                guard HumanAssistedDialog.isAvailable() else {
                    resp.error = "debug-with-user not installed; run: \(HumanAssistedDialog.installHint)"
                    break
                }

                let notifyDir = req.notify_dir ?? workDir
                let title = req.notification_title ?? "Agent session finished"
                let logSeconds = req.log_capture_seconds ?? 30
                let waitSeconds = req.manual_click_wait_seconds ?? 180

                try session.prepareNotificationTest(
                    homeDir: homeDir,
                    workDir: workDir,
                    stateDir: request.state_dir,
                    resp: &resp
                )

                // Phase 1 — first notification + click
                try session.postNotifyAndWaitForBanner(dir: notifyDir, phase: 1, resp: &resp)
                switch HumanAssistedDialog.askProceed(
                    title: "Round 1 — Click the notification",
                    message: """
                    A notification was sent for:
                    \(notifyDir)

                    Click the "\(title)" banner when it appears, then press OK.
                    """,
                    proceedButton: "OK — I clicked it",
                    cancelButton: "Cancel test"
                ) {
                case .affirmed:
                    break
                case .custom(let report):
                    resp.error = "user custom report (round 1 notification click): \(report)"
                    break
                case .dismissed:
                    resp.error = "user dismissed dialog before first notification click"
                    break
                case .denied:
                    resp.error = "user cancelled before first notification click"
                    break
                case .none:
                    resp.error = "debug-with-user failed during round 1 notification click prompt"
                    break
                }
                if !resp.error.isEmpty { break }
                resp.first_notification_clicked = session.waitForManualNotificationClick(
                    notifyDir: notifyDir,
                    title: title,
                    timeout: TimeInterval(waitSeconds),
                    phase: 1,
                    minimumClicks: 1
                )
                if !resp.first_notification_clicked {
                    resp.error = "timed out waiting for first notification click"
                    break
                }
                usleep(2_000_000)

                switch HumanAssistedDialog.askConfirm(
                    title: "Step 1 — Did VS Code open?",
                    message: """
                    A notification was sent and you clicked it.

                    Project folder:
                    \(notifyDir)

                    Did VS Code open (or focus) the window for this project?
                    """,
                    yesButton: "Yes — window opened",
                    noButton: "No — window did not open"
                ) {
                case .affirmed:
                    resp.user_confirmed_window_opened = true
                case .custom(let report):
                    resp.user_report_window_opened = report
                    resp.error = "user custom report (VS Code opened): \(report)"
                case .dismissed:
                    resp.error = "user dismissed dialog at VS Code open confirmation"
                case .denied:
                    resp.error = "user reported VS Code did not open after first notification click"
                case .none:
                    resp.error = "debug-with-user failed during VS Code open confirmation"
                }
                if !resp.error.isEmpty { break }

                switch HumanAssistedDialog.askProceed(
                    title: "Step 2 — Move window to another Space",
                    message: """
                    Move the VS Code window for this project to another macOS Space (desktop):
                    • Swipe with three/four fingers, or press Control+← / Control+→

                    Then leave a different app — or a different VS Code window — focused on this Space.

                    Click OK when you are ready for the second notification.
                    """,
                    proceedButton: "OK — ready for round 2",
                    cancelButton: "Cancel test"
                ) {
                case .affirmed:
                    resp.user_confirmed_desktop_ready = true
                case .custom(let report):
                    resp.user_report_desktop_ready = report
                    resp.error = "user custom report (desktop ready): \(report)"
                case .dismissed:
                    resp.error = "user dismissed dialog before second notification round"
                case .denied:
                    resp.error = "user cancelled before second notification round"
                case .none:
                    resp.error = "debug-with-user failed during desktop ready prompt"
                }
                if !resp.error.isEmpty { break }

                // Phase 2 — second notification + click (window focus parity)
                usleep(1_000_000)
                try session.postNotifyAndWaitForBanner(dir: notifyDir, phase: 2, resp: &resp)
                switch HumanAssistedDialog.askProceed(
                    title: "Round 2 — Click the notification again",
                    message: """
                    A second notification was sent for the same folder:
                    \(notifyDir)

                    Click the banner again, then press OK.
                    """,
                    proceedButton: "OK — I clicked it",
                    cancelButton: "Cancel test"
                ) {
                case .affirmed:
                    break
                case .custom(let report):
                    resp.error = "user custom report (round 2 notification click): \(report)"
                    break
                case .dismissed:
                    resp.error = "user dismissed dialog before second notification click"
                    break
                case .denied:
                    resp.error = "user cancelled before second notification click"
                    break
                case .none:
                    resp.error = "debug-with-user failed during round 2 notification click prompt"
                    break
                }
                if !resp.error.isEmpty { break }
                resp.second_notification_clicked = session.waitForManualNotificationClick(
                    notifyDir: notifyDir,
                    title: title,
                    timeout: TimeInterval(waitSeconds),
                    phase: 2,
                    minimumClicks: 2
                )
                if !resp.second_notification_clicked {
                    resp.error = "timed out waiting for second notification click"
                    break
                }
                usleep(2_000_000)

                switch HumanAssistedDialog.askConfirm(
                    title: "Step 3 — Correct window focused?",
                    message: """
                    You clicked the second notification for the same project folder:
                    \(notifyDir)

                    Did VS Code switch to the correct window (the one on the other Space)?
                    """,
                    yesButton: "Yes — correct window",
                    noButton: "No — wrong window / stayed put"
                ) {
                case .affirmed:
                    resp.user_confirmed_correct_window = true
                case .custom(let report):
                    resp.user_report_correct_window = report
                    resp.error = "user custom report (correct window focused): \(report)"
                case .dismissed:
                    resp.error = "user dismissed dialog at correct window confirmation"
                case .denied:
                    resp.error = "user reported notification click did not focus the correct VS Code window"
                case .none:
                    resp.error = "debug-with-user failed during correct window confirmation"
                }
                if !resp.error.isEmpty { break }

                resp.notification_clicked = true
                resp.click_ok = true
                resp.human_assisted_passed = true

                resp.app_log_path = session.capturedAppLogPath
                resp.app_log_lines = session.readCapturedAppLog()
                resp.log_lines = try session.captureNotificationClickLogs(seconds: logSeconds)
                resp.notification_click_log_lines = resp.log_lines.filter {
                    $0.contains("[NotificationClick]")
                }
                resp.vscode_log_lines = (resp.log_lines + resp.app_log_lines).filter {
                    let lower = $0.lowercased()
                    return lower.contains("vscode") || lower.contains("code_process")
                }
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "notification_window_focus_manual failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "notification_click_e2e":
            do {
                let notifyDir = req.notify_dir ?? workDir
                let title = req.notification_title ?? "Agent session finished"
                let logSeconds = req.log_capture_seconds ?? 45

                session.configureNotificationUITest(
                    homeDir: homeDir,
                    stateDir: request.state_dir,
                    captureAppOutput: true
                )
                try session.configure(homeDir: homeDir, workDir: workDir, stateDir: request.state_dir)
                try session.launchApp(homeDir: homeDir)
                usleep(2_000_000) // baseline poll
                try session.postSessionNotify(dir: notifyDir)
                resp.notification_posted = true
                let snapshot = try session.fetchDaemonEventSnapshot()
                resp.daemon_event_count = snapshot.count
                resp.daemon_has_notify_event = snapshot.dirs.contains(notifyDir)
                _ = session.waitForAppNotificationPosted(timeout: 12)
                usleep(1_000_000)

                let click = try session.clickSessionNotification(title: title, timeout: 8)
                resp.notification_clicked = click.clicked
                resp.click_ok = click.clicked
                resp.click_x = click.x
                resp.click_y = click.y
                usleep(2_000_000) // allow code + vscode activation

                resp.app_log_path = session.capturedAppLogPath
                resp.app_log_lines = session.readCapturedAppLog()
                resp.log_lines = try session.captureNotificationClickLogs(seconds: logSeconds)
                resp.notification_click_log_lines = resp.log_lines.filter {
                    $0.contains("[NotificationClick]")
                }
                resp.vscode_log_lines = (resp.log_lines + resp.app_log_lines).filter {
                    let lower = $0.lowercased()
                    return lower.contains("vscode") || lower.contains("code_process")
                }
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "notification_click_e2e failed"
                }
            } catch {
                resp.error = error.localizedDescription
            }

        case "sequence":
            session.resetDumpCount()
            if let steps = req.sequence {
                for step in steps {
                    if !resp.error.isEmpty { break }
                    handle(step, &resp)
                }
            }

        default:
            resp.error = "unknown action: \(req.action)"
        }
    }

    let projectRoot = (try? UIAutomationSession.findProjectRoot()) ?? FileManager.default.currentDirectoryPath
    defer { session.teardown() }
    do {
        try withAutomationLock(projectRoot: projectRoot) {
            handle(request, &response)
        }
    } catch {
        if response.error.isEmpty {
            response.error = error.localizedDescription
        }
    }

    let encoder = JSONEncoder()
    guard let outputData = try? encoder.encode(response),
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