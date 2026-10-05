// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraceAppsLibrary",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GraceAppsLibrary",
            targets: ["GraceAppsLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GraceAppsLibrary",
            dependencies: [
                .product(name: "TelemetryDeck", package: "SwiftSDK")
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "GraceAppsLibraryTests",
            dependencies: ["GraceAppsLibrary"]),
    ]
)
