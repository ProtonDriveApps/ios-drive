// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDFileProvider",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDFileProvider", targets: ["PDFileProvider"]),
    ],
    dependencies: [
        .package(name: "PDCore", path: "../PDCore"),
        .package(name: "PDUploadVerifier", path: "../PDUploadVerifier"),
        // exact version is defined by PDClient>ProtonCore
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs", .suitable),
    ],
    targets: [
        .target(
            name: "PDFileProvider",
            dependencies: [
                .product(name: "PDCore", package: "PDCore")
            ],
            path: "PDFileProvider"
        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
