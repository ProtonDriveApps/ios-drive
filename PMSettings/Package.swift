// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PMSettings",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "PMSettings", targets: ["PMSettings"]),
    ],
    dependencies: [
        .package(name: "PDLocalization", path: "../PDLocalization"),
        // exact version is defined by PDClient
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", .suitable),
    ],
    targets: [
        .target(
            name: "PMSettings",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore_ios"),
                .product(name: "PDLocalization", package: "PDLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
