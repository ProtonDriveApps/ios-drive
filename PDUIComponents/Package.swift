// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDUIComponents",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDUIComponents", targets: ["PDUIComponents"]),
    ],
    dependencies: [
        .package(name: "PDLocalization", path: "../PDLocalization"),
        // exact version is defined by PDClient
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", .suitable),
    ],
    targets: [
        .target(
            name: "PDUIComponents",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore_ios"),
                .product(name: "PDLocalization", package: "PDLocalization"),
            ],
            path: "PDUIComponents"
        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
