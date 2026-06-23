import Foundation

struct OpenLogsMenuStateResult: Equatable {
    let label: String
    let enabled: Bool
}

enum OpenLogsMenuState {
    static func menuState(infoError: String?) -> OpenLogsMenuStateResult {
        if let infoError, !infoError.isEmpty {
            return OpenLogsMenuStateResult(
                label: "Show Logs in Finder (daemon unreachable)",
                enabled: false
            )
        }
        return OpenLogsMenuStateResult(label: "Show Logs in Finder", enabled: true)
    }

    static func logsViewerMenuState() -> OpenLogsMenuStateResult {
        OpenLogsMenuStateResult(label: "Logs", enabled: true)
    }
}