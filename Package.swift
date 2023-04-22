// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hollywood",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Hollywood",
            targets: [
                "Hollywood"
            ]
        ),
        .library(
            name: "HollywoodUI",
            targets: [
                "HollywoodUI"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
        .package(url: "https://github.com/apple/swift-algorithms", branch: "main"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Hollywood",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags([
                    "-warnings-as-errors",
                    "-strict-concurrency=complete"
                ])
            ]
        ),
        .target(
            name: "HollywoodUI",
            dependencies: [
                "Hollywood"
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-warnings-as-errors",
                    "-strict-concurrency=complete"
                ])
            ]
        ),
        .testTarget(
            name: "HollywoodTests",
            dependencies: [
                "Hollywood"
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-warnings-as-errors",
                    "-strict-concurrency=complete"
                ])
            ]
        )
    ]
)
