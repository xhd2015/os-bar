import Foundation

enum SessionMenuItemFormatter {
    static func tooltip(dir: String) -> String {
        dir
    }

    static func displayLabel(dir: String, consumed: Bool, relativeTime: String) -> String {
        let dot = consumed ? "  " : "● "
        let name = URL(fileURLWithPath: dir).lastPathComponent
        let padded = name.padding(toLength: 22, withPad: " ", startingAt: 0)
        return "\(dot)\(padded) \(relativeTime)"
    }
}