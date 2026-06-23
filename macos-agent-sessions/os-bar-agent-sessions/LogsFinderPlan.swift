import Foundation

struct LogsFinderPlanResult: Equatable {
    let revealKind: String
    let revealPath: String
    let selectRoot: String
}

enum LogsFinderPlan {
    static let logFileName = "notify-logs.jsonl"

    static func plan(storagePath: String) -> LogsFinderPlanResult {
        let logPath = (storagePath as NSString).appendingPathComponent(logFileName)
        if FileManager.default.fileExists(atPath: logPath) {
            return LogsFinderPlanResult(
                revealKind: "file",
                revealPath: logPath,
                selectRoot: storagePath
            )
        }
        return LogsFinderPlanResult(
            revealKind: "directory",
            revealPath: storagePath,
            selectRoot: ""
        )
    }
}