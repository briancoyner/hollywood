// swift-tools-version: 5.9
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
            swiftSettings: [
                .strictConcurrency,
                .existentialAny,
                .forwardTrailingClosure
            ]
        ),
        .testTarget(
            name: "HollywoodTests",
            dependencies: [
                "Hollywood"
            ],
            swiftSettings: [
                .strictConcurrency,
                .existentialAny,
                .forwardTrailingClosure
            ]
        )
    ]
)

// MARK: - Swift Settings

extension SwiftSetting {

    static var existentialAny: SwiftSetting {
        return .enableUpcomingFeature("ExistentialAny")
    }

    static var forwardTrailingClosure: SwiftSetting {
        return .enableUpcomingFeature("ForwardTrailingClosure")
    }

    static var strictConcurrency: SwiftSetting {
        return .enableExperimentalFeature("StrictConcurrency=complete")
    }
}
