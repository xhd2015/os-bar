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
            activateApp()
        }
        openSessionDir(dir)
    }
}