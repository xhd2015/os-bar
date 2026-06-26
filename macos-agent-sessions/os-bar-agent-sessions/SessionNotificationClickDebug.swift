import AppKit
import Foundation

/// Structured debug logging for notification → open-session click flow.
/// Active only in debug builds (`AGENT_SESSIONS_DEBUG`). Filter Console.app with: `[NotificationClick]`
enum SessionNotificationClickDebug {
    private static let prefix = "[NotificationClick]"
    private static let vscodeBundleID = "com.microsoft.VSCode"

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ step: String, _ details: [String: String] = [:]) {
        #if AGENT_SESSIONS_DEBUG
        let timestamp = timestampFormatter.string(from: Date())
        let line: String
        if details.isEmpty {
            line = "\(prefix) \(timestamp) \(step)"
        } else {
            let detailText = details
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\(quoteIfNeeded($0.value))" }
                .joined(separator: " ")
            line = "\(prefix) \(timestamp) \(step) | \(detailText)"
        }
        print(line)
        appendToDebugLogFile(line)
        #endif
    }

    private static func appendToDebugLogFile(_ line: String) {
        #if AGENT_SESSIONS_DEBUG
        guard let path = resolvedDebugLogPath() else { return }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: url)
        {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
        #endif
    }

    private static func resolvedDebugLogPath() -> String? {
        #if AGENT_SESSIONS_DEBUG
        if let path = ProcessInfo.processInfo.environment["AGENT_SESSIONS_NOTIFICATION_DEBUG_LOG"],
           !path.isEmpty
        {
            return path
        }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return (home as NSString).appendingPathComponent(".os-bar/agent-sessions-debug.log")
        #else
        return nil
        #endif
    }

    static func snapshotContext(step: String) {
        #if AGENT_SESSIONS_DEBUG
        log(step, [
            "frontmost_app": frontmostAppDescription(),
            "nsapp_active": String(NSApp.isActive),
            "nsapp_hidden": String(NSApp.isHidden),
            "activation_policy": activationPolicyDescription(),
            "vscode_instances": vscodeInstancesDescription(),
            "code_binary_exists": String(FileManager.default.fileExists(atPath: SessionDirCommand.binary)),
        ])
        #endif
    }

    #if AGENT_SESSIONS_DEBUG
    private static func frontmostAppDescription() -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return "none"
        }
        let name = app.localizedName ?? "?"
        let bundleID = app.bundleIdentifier ?? "?"
        return "\(name)(\(bundleID)) pid=\(app.processIdentifier) active=\(app.isActive)"
    }

    private static func activationPolicyDescription() -> String {
        switch NSApp.activationPolicy() {
        case .regular: return "regular"
        case .accessory: return "accessory"
        case .prohibited: return "prohibited"
        @unknown default: return "unknown"
        }
    }

    private static func vscodeInstancesDescription() -> String {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: vscodeBundleID)
        if apps.isEmpty {
            return "none"
        }
        return apps.map { app in
            "pid=\(app.processIdentifier) active=\(app.isActive) hidden=\(app.isHidden)"
        }.joined(separator: "; ")
    }
    #endif

    static func logVSCodeActivationAttempt(exitCode: Int32) -> Bool {
        #if AGENT_SESSIONS_DEBUG
        guard exitCode == 0 else {
            log("skip_vscode_activation", ["exit_code": String(exitCode)])
            return false
        }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: vscodeBundleID)
        log("vscode_activation_attempt", [
            "instance_count": String(apps.count),
            "instances_before": vscodeInstancesDescription(),
            "frontmost_before": frontmostAppDescription(),
        ])

        guard let app = apps.first else {
            log("vscode_activation_failed", ["reason": "no_running_vscode_instance"])
            return false
        }

        let activated = app.activate(options: [.activateIgnoringOtherApps])
        log("vscode_activation_result", [
            "activated": String(activated),
            "target_pid": String(app.processIdentifier),
            "frontmost_after": frontmostAppDescription(),
            "instances_after": vscodeInstancesDescription(),
        ])
        return activated
        #else
        return false
        #endif
    }

    #if AGENT_SESSIONS_DEBUG
    private static func quoteIfNeeded(_ value: String) -> String {
        if value.contains(" ") || value.isEmpty {
            return "\"\(value)\""
        }
        return value
    }
    #endif
}