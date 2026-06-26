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
        guard notificationsEnabled else {
            if AgentSessionsDebug.isEnabled {
                Task { await logNotificationDiagnostics(context: "configure_disabled_not_app_bundle") }
            }
            return
        }
        UNUserNotificationCenter.current().delegate = self
        if AgentSessionsDebug.isEnabled {
            Task { await logNotificationDiagnostics(context: "configure") }
        }
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

        if AgentSessionsDebug.isEnabled, !toNotify.isEmpty {
            await logNotificationDiagnostics(context: "handle_refresh_notify_\(toNotify.count)")
        }

        for dir in toNotify {
            await postSessionFinished(dir: dir)
        }
    }

    func postSessionFinished(dir: String) async {
        guard notificationsEnabled else { return }
        await ensureAuthorization()
        if AgentSessionsDebug.isEnabled {
            await logNotificationDiagnostics(context: "post_session_finished")
        }

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
            SessionNotificationClickDebug.log("notification_posted", [
                "dir": dir,
                "identifier": identifier,
                "title": content.title,
            ])
        } catch {
            print("SessionNotificationService: failed to post notification: \(error)")
            SessionNotificationClickDebug.log("notification_post_failed", [
                "dir": dir,
                "error": String(describing: error),
            ])
        }
    }

    func handleNotificationClick(dir: String) {
        SessionNotificationClickDebug.log("handle_notification_click", [
            "dir": dir,
            "app_delegate_present": String(appDelegate != nil),
        ])
        SessionClickHandler.handleClick(
            dir: dir,
            source: .notification,
            // Keep the activate hook for the notification click contract, but do not
            // call NSApp.activate here — it foregrounds the menu-bar agent, not VS Code,
            // and causes activateVSCodeIfNeeded to restore the wrong workspace window.
            activateApp: {},
            openSessionDir: { [weak self] dir in
                guard let self else {
                    SessionNotificationClickDebug.log("open_session_aborted", [
                        "reason": "notification_service_deallocated",
                        "dir": dir,
                    ])
                    return
                }
                guard let appDelegate = self.appDelegate else {
                    SessionNotificationClickDebug.log("open_session_aborted", [
                        "reason": "app_delegate_nil",
                        "dir": dir,
                    ])
                    return
                }
                SessionNotificationClickDebug.log("open_session_dir_call", ["dir": dir])
                appDelegate.openSessionDir(dir, source: .notification)
            }
        )
        SessionNotificationClickDebug.log("handle_notification_click_finished", ["dir": dir])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        let notificationID = response.notification.request.identifier

        SessionNotificationClickDebug.log("delegate_did_receive", [
            "action": actionIdentifier,
            "notification_id": notificationID,
            "user_info": String(describing: userInfo),
            "thread": Thread.isMainThread ? "main" : "background",
        ])

        guard let dir = userInfo["dir"] as? String else {
            SessionNotificationClickDebug.log("delegate_missing_dir", [
                "action": actionIdentifier,
                "notification_id": notificationID,
                "user_info": String(describing: userInfo),
            ])
            completionHandler()
            return
        }

        Task { @MainActor in
            SessionNotificationClickDebug.log("main_actor_task_started", [
                "dir": dir,
                "action": actionIdentifier,
            ])
            SessionNotificationClickDebug.snapshotContext(step: "main_actor_task_entry")
            self.handleNotificationClick(dir: dir)
            SessionNotificationClickDebug.log("completion_handler_invoked", ["dir": dir])
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
            SessionNotificationClickDebug.log("notification_authorization_requested", [
                "granted": String(granted),
            ])
            if !granted {
                print("SessionNotificationService: notification permission denied; menu-bar-only fallback")
            }
        } catch {
            print("SessionNotificationService: authorization request failed: \(error)")
            SessionNotificationClickDebug.log("notification_authorization_failed", [
                "error": String(describing: error),
            ])
        }
        if AgentSessionsDebug.isEnabled {
            await logNotificationDiagnostics(context: "after_authorization_request")
        }
    }

    private func logNotificationDiagnostics(context: String) async {
        guard AgentSessionsDebug.isEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        SessionNotificationClickDebug.log("notification_diagnostics", [
            "context": context,
            "authorization": authorizationStatusName(settings.authorizationStatus),
            "bundle_id": Bundle.main.bundleIdentifier ?? "",
            "bundle_is_app": String(notificationsEnabled),
            "alert_setting": settingName(settings.alertSetting),
            "notification_center_setting": settingName(settings.notificationCenterSetting),
            "lock_screen_setting": settingName(settings.lockScreenSetting),
            "banner_setting": settingName(settings.alertSetting),
        ])
    }

    private func authorizationStatusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private func settingName(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "notSupported"
        case .disabled: return "disabled"
        case .enabled: return "enabled"
        @unknown default: return "unknown"
        }
    }

    private func notificationIdentifier(for dir: String) -> String {
        let sanitized = dir.replacingOccurrences(of: "/", with: "-")
        return "session-\(sanitized)"
    }
}