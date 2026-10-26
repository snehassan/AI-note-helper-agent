// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NoteBuddy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "NoteBuddy", path: "Sources/NoteBuddy")
    ]
)
