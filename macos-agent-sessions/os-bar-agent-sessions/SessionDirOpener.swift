import Foundation

/// Fixed kool install locations (no PATH lookup).
enum SessionKoolBinary {
    static let candidates = [
        "/usr/bin/kool",
        "/usr/local/bin/kool",
        "/Users/xhd2015/go/bin/kool",
    ]

    static func resolve() -> String? {
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    static func commandLine(binary: String, dir: String) -> String {
        "\(binary) vscode open \(dir) --ipc-only --json"
    }
}

struct KoolVSCodeOpenJSON: Decodable {
    let ipcHandled: Bool

    enum CodingKeys: String, CodingKey {
        case ipcHandled = "ipc_handled"
    }
}

/// Outcome of attempting kool IPC open (notification clicks only).
struct SessionKoolOpenAttempt {
    let attempted: Bool
    let binary: String?
    let commandLine: String
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let ipcHandled: Bool
    let parseError: Bool
    let launchFailed: Bool

    var fallbackReason: String? {
        if !attempted { return "kool_missing" }
        if launchFailed { return "kool_launch_failed" }
        if parseError { return "kool_json_parse_error" }
        if !ipcHandled { return "kool_ipc_not_handled" }
        return nil
    }
}

enum SessionKoolOpenRunner {
    static func run(binary: String, dir: String) -> SessionKoolOpenAttempt {
        let commandLine = SessionKoolBinary.commandLine(binary: binary, dir: dir)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["vscode", "open", dir, "--ipc-only", "--json"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return SessionKoolOpenAttempt(
                attempted: true,
                binary: binary,
                commandLine: commandLine,
                exitCode: -1,
                stdout: "",
                stderr: "failed to launch: \(error.localizedDescription)",
                ipcHandled: false,
                parseError: false,
                launchFailed: true
            )
        }

        process.waitUntilExit()
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        var ipcHandled = false
        var parseError = false
        if let data = stdout.data(using: .utf8) {
            if let decoded = try? JSONDecoder().decode(KoolVSCodeOpenJSON.self, from: data) {
                ipcHandled = decoded.ipcHandled
            } else {
                parseError = true
            }
        } else {
            parseError = true
        }

        return SessionKoolOpenAttempt(
            attempted: true,
            binary: binary,
            commandLine: commandLine,
            exitCode: process.terminationStatus,
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            ipcHandled: ipcHandled && process.terminationStatus == 0,
            parseError: parseError,
            launchFailed: false
        )
    }
}

/// Fields merged into a single `command.executed` log line for notification opens.
struct SessionNotificationOpenLogMeta {
    let openMethod: String
    let koolAttempted: Bool
    let koolIpcHandled: Bool?
    let fallbackReason: String?

    static func forKoolSuccess() -> SessionNotificationOpenLogMeta {
        SessionNotificationOpenLogMeta(
            openMethod: "kool_ipc",
            koolAttempted: true,
            koolIpcHandled: true,
            fallbackReason: nil
        )
    }

    static func forCodeFallback(kool: SessionKoolOpenAttempt?) -> SessionNotificationOpenLogMeta {
        if let kool, kool.attempted {
            return SessionNotificationOpenLogMeta(
                openMethod: "code_cli",
                koolAttempted: true,
                koolIpcHandled: false,
                fallbackReason: kool.fallbackReason
            )
        }
        return SessionNotificationOpenLogMeta(
            openMethod: "code_cli",
            koolAttempted: false,
            koolIpcHandled: nil,
            fallbackReason: "kool_missing"
        )
    }
}