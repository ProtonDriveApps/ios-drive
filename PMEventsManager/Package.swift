// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PMEventsManager",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)]
    ,
    products: [
        .library(name: "PMEventsManager", targets: ["PMEventsManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", exact: "32.7.1"),
    ],
    targets: [
        .target(
            name: "PMEventsManager",
            dependencies: [
                .product(name: "ProtonCoreDataModel", package: "protoncore_ios"),
                .product(name: "ProtonCoreNetworking", package: "protoncore_ios"),
                .product(name: "ProtonCoreServices", package: "protoncore_ios"),
                .product(name: "ProtonCorePayments", package: "protoncore_ios"),
            ],
            path: "Sources"
        ),
    ]
)
