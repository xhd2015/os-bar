import AppKit
import Foundation

@MainActor
enum LogsFinderOpener {
    static func openLogs(client: DaemonClient = .shared) async {
        do {
            let info = try await client.info()
            let plan = LogsFinderPlan.plan(storagePath: info.storagePath)
            reveal(plan: plan)
        } catch {
            // Menu should be disabled when info fails; no Finder action.
        }
    }

    private static func reveal(plan: LogsFinderPlanResult) {
        switch plan.revealKind {
        case "file":
            NSWorkspace.shared.selectFile(plan.revealPath, inFileViewerRootedAtPath: plan.selectRoot)
        case "directory":
            let url = URL(fileURLWithPath: plan.revealPath, isDirectory: true)
            NSWorkspace.shared.open(url)
        default:
            break
        }
    }
}