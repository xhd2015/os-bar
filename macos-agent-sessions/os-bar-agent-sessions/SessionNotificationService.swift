import AppKit
import Foundation
import UserNotifications

struct SessionNotificationContent {
    let title: String
    let body: String
    let subtitle: String
    let userInfoDir: String
}

struct DirTimestampPair: Hashable {
    let dir: String
    let timestamp: Date
}

enum SessionNotificationLogic {
    static let title = "Agent session finished"

    static func dirsNeedingNotification(
        previous: [SessionEvent],
        current: [SessionEvent],
        isBaseline: Bool
    ) -> [String] {
        if isBaseline {
            return []
        }

        let previousPairs = Set(previous.map { DirTimestampPair(dir: $0.dir, timestamp: $0.timestamp) })
        var notifyDirs: [String] = []
        for event in current {
            let pair = DirTimestampPair(dir: event.dir, timestamp: event.timestamp)
            if !previousPairs.contains(pair) {
                notifyDirs.append(event.dir)
            }
        }
        return notifyDirs
    }

    static func buildContent(
        dir: String,
        home: String? = nil,
        cwd: String? = nil
    ) -> SessionNotificationContent {
        let body = URL(fileURLWithPath: dir).lastPathComponent
        let parent = URL(fileURLWithPath: dir).deletingLastPathComponent().path
        let subtitle = shortenPath(
            parent,
            home: home ?? NSHomeDirectory(),
            cwd: cwd ?? FileManager.default.currentDirectoryPath
        )
        return SessionNotificationContent(
            title: title,
            body: body,
            subtitle: subtitle,
            userInfoDir: dir
        )
    }

    static func shortenPath(_ path: String, home: String, cwd: String) -> String {
        guard !path.isEmpty else { return path }

        let abs = (path as NSString).standardizingPath
        let cwdAbs = (cwd as NSString).standardizingPath

        if abs == cwdAbs {
            return "."
        }

        if let rel = relativePath(from: cwdAbs, to: abs), rel != ".", !rel.hasPrefix("..") {
            return rel
        }

        if abs == home {
            return "~"
        }

        let homePrefix = home + "/"
        if abs.hasPrefix(homePrefix) {
            return "~" + String(abs.dropFirst(home.count))
        }

        return abs
    }

    private static func relativePath(from base: String, to target: String) -> String? {
        let basePath = (base as NSString).standardizingPath
        let targetPath = (target as NSString).standardizingPath

        let baseComps = pathComponents(basePath)
        let targetComps = pathComponents(targetPath)

        var common = 0
        while common < baseComps.count && common < targetComps.count && baseComps[common] == targetComps[common] {
            common += 1
        }

        let upCount = baseComps.count - common
        let downComps = Array(targetComps[common...])

        if upCount == 0 && downComps.isEmpty {
            return "."
        }

        if upCount > 0 {
            let ups = Array(repeating: "..", count: upCount)
            return (ups + downComps).joined(separator: "/")
        }

        return downComps.joined(separator: "/")
    }

    private static func pathComponents(_ path: String) -> [String] {
        if path == "/" {
            return []
        }
        return path.split(separator: "/").map(String.init)
    }
}

@MainActor
final class SessionNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private weak var appDelegate: AppDelegate?
    private var isFirstPoll = true
    private var didRequestAuthorization = false

    /// UserNotifications requires a proper .app bundle; `swift build` debug binaries crash on access.
    private var notificationsEnabled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func configure(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        guard notificationsEnabled else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func handleRefresh(previous: [SessionEvent], current: [SessionEvent]) async {
        let isBaseline = isFirstPoll
        isFirstPoll = false
        guard notificationsEnabled else { return }

        let toNotify = SessionNotificationLogic.dirsNeedingNotification(
            previous: previous,
            current: current,
            isBaseline: isBaseline
        )

        for dir in toNotify {
            await postSessionFinished(dir: dir)
        }
    }

    func postSessionFinished(dir: String) async {
        guard notificationsEnabled else { return }
        await ensureAuthorization()

        let content = SessionNotificationLogic.buildContent(dir: dir)
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body
        notificationContent.subtitle = content.subtitle
        notificationContent.sound = .default
        notificationContent.userInfo = ["dir": content.userInfoDir]

        let identifier = notificationIdentifier(for: dir)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("SessionNotificationService: failed to post notification: \(error)")
        }
    }

    func handleNotificationClick(dir: String) {
        SessionClickHandler.handleClick(
            dir: dir,
            source: .notification,
            activateApp: { NSApp.activate(ignoringOtherApps: true) },
            openSessionDir: { [weak self] dir in
                self?.appDelegate?.openSessionDir(dir)
            }
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let dir = userInfo["dir"] as? String else {
            completionHandler()
            return
        }

        Task { @MainActor in
            self.handleNotificationClick(dir: dir)
            completionHandler()
        }
    }

    private func ensureAuthorization() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
            if !granted {
                print("SessionNotificationService: notification permission denied; menu-bar-only fallback")
            }
        } catch {
            print("SessionNotificationService: authorization request failed: \(error)")
        }
    }

    private func notificationIdentifier(for dir: String) -> String {
        let sanitized = dir.replacingOccurrences(of: "/", with: "-")
        return "session-\(sanitized)"
    }
}