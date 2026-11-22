// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraceAppsLibrary",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GraceAppsLibrary",
            targets: ["GraceAppsLibrary"]),
        .library(
            name: "GraceAppsLibraryAdMob",
            targets: ["GraceAppsLibraryAdMob"]),
        .library(
            name: "GraceAppsLibraryRevenueCat",
            targets: ["GraceAppsLibraryRevenueCat"]),
        .plugin(
            name: "GALValidatorPlugin",
            targets: ["GALValidatorPlugin"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            "12.0.0"..<"15.0.0"
        ),
        .package(
            url: "https://github.com/RevenueCat/purchases-ios.git",
            "5.0.0"..<"6.0.0"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GraceAppsLibrary",
            dependencies: [],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "GraceAppsLibraryAdMob",
            dependencies: [
                "GraceAppsLibrary",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ]
        ),
        .target(
            name: "GraceAppsLibraryRevenueCat",
            dependencies: [
                "GraceAppsLibrary",
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "RevenueCatUI", package: "purchases-ios"),
            ]
        ),
        .testTarget(
            name: "GraceAppsLibraryTests",
            dependencies: ["GraceAppsLibrary"]),
        .testTarget(
            name: "GraceAppsLibraryAdMobTests",
            dependencies: [
                "GraceAppsLibraryAdMob",
                "GraceAppsLibrary",
            ]),
        .testTarget(
            name: "GraceAppsLibraryRevenueCatTests",
            dependencies: [
                "GraceAppsLibraryRevenueCat",
                "GraceAppsLibrary",
            ]),
        .plugin(
            name: "GALValidatorPlugin",
            capability: .buildTool()),
    ]
)
