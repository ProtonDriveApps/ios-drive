// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDUploadVerifier",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDUploadVerifier", targets: ["PDUploadVerifier"]),
    ],
    dependencies: [
        .package(name: "PDCore", path: "../PDCore"),
    ],
    targets: [
        .target(
            name: "PDUploadVerifier",
            dependencies: [
                .product(name: "PDCore", package: "PDCore"),
            ],
            path: "PDUploadVerifier"
        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
