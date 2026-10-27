// swift-tools-version: 5.9

// An app package: opens in Xcode, or in Swift Playgrounds on iPad.
import AppleProductTypes
import PackageDescription

let package = Package(
    name: "NoteBuddy",
    platforms: [.iOS("17.0")],
    products: [
        .iOSApplication(
            name: "NoteBuddy",
            targets: ["AppModule"],
            bundleIdentifier: "dev.notebuddy.ipad",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .pencil),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad])),
            ],
            appCategory: .productivity
        )
    ],
    targets: [
        .executableTarget(name: "AppModule", path: ".")
    ]
)
