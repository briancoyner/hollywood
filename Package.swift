// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hollywood",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Hollywood",
            targets: [
                "Hollywood"
            ]
        )
    ],
    dependencies: [
        // None
    ],
    targets: [
        .target(
            name: "Hollywood",
            dependencies: [
                // None
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HollywoodTests",
            dependencies: [
                "Hollywood"
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [
        .v6
    ]
)

// MARK: - Swift Settings

private var swiftSettings: [SwiftSetting] {
    return [
        .enableUpcomingFeature("ExistentialAny")
    ]
}
