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
    private var dumpCount = 0
    private var projectRoot = ""
    private var cliPath = ""

    private init() {}

    func resetDumpCount() {
        dumpCount = 0
    }

    func configure(homeDir: String, workDir: String) throws {
        projectRoot = try Self.findProjectRoot()
        cliPath = try Self.buildCLI(projectRoot: projectRoot)
        _ = homeDir
        _ = workDir
    }

    func openSettings(homeDir: String) throws {
        if appProcess != nil {
            return
        }

        let appPath = try Self.buildApp(projectRoot: projectRoot)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        process.arguments = ["-uiTestingOpenSettings"]

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = homeDir
        env["AGENT_SESSIONS_CLI"] = cliPath
        let cliDir = (cliPath as NSString).deletingLastPathComponent
        env["PATH"] = "\(cliDir):" + (env["PATH"] ?? "")
        process.environment = env

        try process.run()
        appProcess = process
        appPID = process.processIdentifier

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if let window = try findIntegrationsWindow(),
               let layout = try? serializeElement(window),
               treeContainsIdentifier(layout, id: "integration-grok") {
                return
            }
            usleep(200_000)
        }
        throw AutomationError.timeout("Integrations window did not appear")
    }

    func dumpLayout() throws -> AXNode {
        guard let window = try findIntegrationsWindow() else {
            throw AutomationError.windowNotFound
        }
        return try serializeElement(window)
    }

    func click(identifier: String?, role: String?, title: String?) throws -> (ok: Bool, x: Double, y: Double) {
        guard let window = try findIntegrationsWindow() else {
            throw AutomationError.windowNotFound
        }
        guard let target = try findElement(in: window, identifier: identifier, role: role, title: title) else {
            return (false, 0, 0)
        }

        var clickPoint = CGPoint.zero
        if let frame = try axFrame(target) {
            clickPoint = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
        }

        let pressed = AXUIElementPerformAction(target, kAXPressAction as CFString)
        if pressed != .success {
            if clickPoint != .zero {
                clickAtScreenPoint(clickPoint)
            } else {
                return (false, 0, 0)
            }
        }

        if clickPoint == .zero, let frame = try axFrame(target) {
            clickPoint = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
        }

        return (true, Double(clickPoint.x), Double(clickPoint.y))
    }

    func teardown() {
        if let process = appProcess {
            if process.isRunning {
                process.terminate()
                let deadline = Date().addingTimeInterval(3)
                while process.isRunning && Date() < deadline {
                    usleep(100_000)
                }
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                process.waitUntilExit()
            }
        }
        appProcess = nil
        appPID = 0
        dumpCount = 0
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
                return window
            }
            if let subtree = try? serializeElement(window),
               treeContainsIdentifier(subtree, id: "integrations-window") {
                return window
            }
        }
        return nil
    }

    private func treeContainsIdentifier(_ node: AXNode, id: String) -> Bool {
        if node.identifier == id { return true }
        guard let children = node.children else { return false }
        return children.contains { treeContainsIdentifier($0, id: id) }
    }

    private func findElement(
        in root: AXUIElement,
        identifier: String?,
        role: String?,
        title: String?
    ) throws -> AXUIElement? {
        var stack = [root]
        while !stack.isEmpty {
            let element = stack.removeLast()
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

    private func serializeElement(_ element: AXUIElement) throws -> AXNode {
        let role = try axRole(element)
        var title = try axString(element, kAXTitleAttribute as CFString)
        let identifier = try axString(element, kAXIdentifierAttribute as CFString)
        let value = try axString(element, kAXValueAttribute as CFString)
        if title == nil, role == "AXStaticText", let value {
            title = value
        }
        let frame = try axFrame(element)
        let childrenAX = try axChildren(element) ?? []
        let children = try childrenAX.map { try serializeElement($0) }

        return AXNode(
            role: role,
            title: title,
            identifier: identifier,
            value: value,
            frame: frame,
            children: children.isEmpty ? nil : children
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
        let src = CGEventSource(stateID: .combinedSessionState)
        if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
           let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) {
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

func withAutomationLock<T>(projectRoot: String, _ body: () throws -> T) rethrows -> T {
    let lockDir = (projectRoot as NSString).appendingPathComponent(".build")
    try? FileManager.default.createDirectory(atPath: lockDir, withIntermediateDirectories: true)
    let lockPath = (lockDir as NSString).appendingPathComponent("ui-automation.lock")
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
    if fd >= 0 {
        flock(fd, LOCK_EX)
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
                let result = try session.click(
                    identifier: req.identifier,
                    role: req.role,
                    title: req.title
                )
                resp.click_ok = result.ok
                resp.click_x = result.x
                resp.click_y = result.y
                if req.wait_ms ?? 0 > 0 {
                    usleep(useconds_t(req.wait_ms!) * 1000)
                } else {
                    usleep(500_000)
                }
            } catch let error as UIAutomationSession.AutomationError {
                if case .apiDisabled = error {
                    resp.error = error.localizedDescription ?? "kAXErrorAPIDisabled (-25211)"
                } else {
                    resp.error = error.localizedDescription ?? "click failed"
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
    withAutomationLock(projectRoot: projectRoot) {
        handle(request, &response)
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