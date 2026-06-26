import Foundation

enum SessionClickSource: Equatable {
    case menuBar
    case notification
}

enum SessionDirCommand {
    static let binary = "/usr/local/bin/code"

    static func line(for dir: String) -> String {
        "\(binary) \(dir)"
    }
}

enum SessionClickHandler {
    static func handleClick(
        dir: String,
        source: SessionClickSource,
        activateApp: () -> Void,
        openSessionDir: (String) -> Void
    ) {
        if source == .notification {
            SessionNotificationClickDebug.log("handle_click_start", ["dir": dir])
            SessionNotificationClickDebug.snapshotContext(step: "before_activate_hook")
            activateApp()
            SessionNotificationClickDebug.log("activate_hook_finished", [
                "note": "notification path intentionally skips NSApp.activate",
            ])
            SessionNotificationClickDebug.snapshotContext(step: "after_activate_hook")
        }
        openSessionDir(dir)
        if source == .notification {
            SessionNotificationClickDebug.log("handle_click_dispatched_open", ["dir": dir])
        }
    }
}