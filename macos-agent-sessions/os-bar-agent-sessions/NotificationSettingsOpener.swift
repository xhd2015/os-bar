import AppKit
import Foundation

enum NotificationSettingsOpener {
    static let modernSettingsPath = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
    static let legacySettingsPath = "x-apple.systempreferences:com.apple.preference.notifications"
    static let defaultBundleID = "com.os-bar.agent-sessions"

    static func settingsURL(bundleID: String) -> URL? {
        URL(string: "\(modernSettingsPath)?id=\(bundleID)")
            ?? URL(string: "\(legacySettingsPath)?id=\(bundleID)")
    }

    static func open(bundleID: String? = nil) {
        let resolvedBundleID = bundleID ?? Bundle.main.bundleIdentifier ?? defaultBundleID
        guard let url = settingsURL(bundleID: resolvedBundleID) else { return }
        NSWorkspace.shared.open(url)
    }
}