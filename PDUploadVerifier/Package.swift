// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDUploadVerifier",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDUploadVerifier", targets: ["PDUploadVerifier"]),
    ],
    dependencies: [
        .package(name: "PDCore", path: "../PDCore"),
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", exact: "32.7.1"),
    ],
    targets: [
        .target(
            name: "PDUploadVerifier",
            dependencies: [
                .product(name: "PDCore", package: "PDCore"),
                .product(name: "ProtonCoreKeyManager", package: "protoncore_ios"),
            ],
            path: "PDUploadVerifier"
        ),
    ]
)
