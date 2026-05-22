// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppPulse",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AppPulse",
            path: "Sources/AppPulse"
        )
    ]
)
