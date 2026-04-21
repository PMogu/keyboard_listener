// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyboardListenerMac",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "KeyboardListenerMac",
            targets: ["KeyboardListenerMac"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "KeyboardListenerMac",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v5,
    ]
)
