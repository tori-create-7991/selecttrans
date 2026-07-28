// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NaniMini",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "NaniMini",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/NaniMini",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NaniMiniTests",
            dependencies: ["NaniMini"],
            path: "Tests/NaniMiniTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
