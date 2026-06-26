import Foundation

/// Debug-only features (notification tracing, diagnostics, default debug log file).
/// Enabled when built with `-c debug` via Package.swift `AGENT_SESSIONS_DEBUG`.
enum AgentSessionsDebug {
    static var isEnabled: Bool {
        #if AGENT_SESSIONS_DEBUG
        return true
        #else
        return false
        #endif
    }

    static let bundleID = "com.os-bar.agent-sessions.debug"
    static let appName = "os-bar-agent-sessions-debug"
}