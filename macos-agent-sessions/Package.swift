// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "os-bar-agent-sessions",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "os-bar-agent-sessions", targets: ["os-bar-agent-sessions"]),
    ],
    targets: [
        .executableTarget(
            name: "os-bar-agent-sessions",
            path: "os-bar-agent-sessions",
            swiftSettings: [
                .define("AGENT_SESSIONS_DEBUG", .when(configuration: .debug)),
            ]
        ),
    ]
)
