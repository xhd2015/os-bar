import Foundation

struct OpenLogsMenuStateResult: Equatable {
    let label: String
    let enabled: Bool
}

enum OpenLogsMenuState {
    static func menuState(infoError: String?) -> OpenLogsMenuStateResult {
        if let infoError, !infoError.isEmpty {
            return OpenLogsMenuStateResult(
                label: "Open Logs (daemon unreachable)",
                enabled: false
            )
        }
        return OpenLogsMenuStateResult(label: "Open Logs", enabled: true)
    }
}