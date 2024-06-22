// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hollywood",
    platforms: [
        .iOS(.v18),
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
        .package(url: "https://github.com/apple/swift-docc-plugin", exact: "1.3.0")
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
    swiftLanguageVersions: [
        .v6
    ]
)

// MARK: - Swift Settings

private var swiftSettings: [SwiftSetting] {
    return [
        .enableUpcomingFeature("ExistentialAny")
    ]
}
