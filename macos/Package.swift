// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "os-bar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "os-bar", targets: ["os-bar"]),
    ],
    targets: [
        .executableTarget(
            name: "os-bar",
            path: "os-bar"
        ),
    ]
)
