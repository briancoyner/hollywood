// swift-tools-version: 5.7
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
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Hollywood",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-warnings-as-errors"
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
                    "-warnings-as-errors"
                ])
            ]
        )
    ]
)
