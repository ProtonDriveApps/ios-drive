// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDLocalization",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PDLocalization", targets: ["PDLocalization"]),
    ],
    targets: [
        .target(
            name: "PDLocalization"
        ),
    ]
)
