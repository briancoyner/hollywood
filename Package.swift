// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hollywood",
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
    ]
)

// MARK: - Swift Settings

private var swiftSettings: [SwiftSetting] {
    return [
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .enableUpcomingFeature("ConciseMagicFile"),
        .enableUpcomingFeature("ForwardTrailingClosures"),
        .enableUpcomingFeature("ImportObjcForwardDeclarations"),
        .enableUpcomingFeature("DisableOutwardActorInference"),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("DeprecateApplicationMain"),
        .enableUpcomingFeature("GlobalConcurrency"),
        .enableUpcomingFeature("IsolatedDefaultValues"),
        .enableExperimentalFeature("StrictConcurrency=complete")
    ]
}
