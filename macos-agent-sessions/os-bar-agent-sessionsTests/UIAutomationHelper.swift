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

    private init() {}

    func resetDumpCount() {
        dumpCount = 0
    }

    func configure(homeDir: String, workDir: String) throws {
        projectRoot = try Self.findProjectRoot()
        cliPath = try Self.buildCLI(projectRoot: projectRoot)
        daemonPort = try Self.pickEphemeralPort()
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

    func launchApp(homeDir: String) throws {
        try launchApp(homeDir: homeDir, uiTestingOpenSettings: false)
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if appProcess?.isRunning == true, try daemonHealthy() {
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
        stateDir = (homeDir as NSString).appendingPathComponent(".os-bar/agent-sessions")
        try ensureDaemonRunning(homeDir: homeDir)

        let appPath = try Self.buildApp(projectRoot: projectRoot)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        if uiTestingOpenSettings {
            process.arguments = ["-uiTestingOpenSettings"]
        }

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = homeDir
        env["AGENT_SESSIONS_CLI"] = cliPath
        env["AGENT_SESSIONS_PORT"] = String(daemonPort)
        env["AGENT_SESSIONS_STATE_DIR"] = stateDir
        let cliDir = (cliPath as NSString).deletingLastPathComponent
        env["PATH"] = "\(cliDir):" + (env["PATH"] ?? "")
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        appProcess = process
        appPID = process.processIdentifier
        integrationsWindow = nil
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