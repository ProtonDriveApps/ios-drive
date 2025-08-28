// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDUIComponents",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDUIComponents", targets: ["PDUIComponents"]),
    ],
    dependencies: [
        .package(name: "PDLocalization", path: "../PDLocalization"),
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", exact: "32.7.1"),
    ],
    targets: [
        .target(
            name: "PDUIComponents",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore_ios"),
                .product(name: "PDLocalization", package: "PDLocalization"),
            ],
            path: "PDUIComponents",
            resources: [
                .process("Media.xcassets") // ✅ Include asset catalog
            ]
        ),
    ]
)
