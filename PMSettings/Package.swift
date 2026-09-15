// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PMSettings",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "PMSettings", targets: ["PMSettings"]),
    ],
    dependencies: [
        .package(name: "PDLocalization", path: "../PDLocalization"),
        .package(name: "PDUIComponents", path: "../PDUIComponents"),
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", exact: "37.3.0"),
    ],
    targets: [
        .target(
            name: "PMSettings",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore_ios"),
                .product(name: "PDLocalization", package: "PDLocalization"),
                .product(name: "PDUIComponents", package: "PDUIComponents"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
