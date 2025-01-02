// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDContacts",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "PDContacts", targets: ["PDContacts"]),
    ],
    dependencies: [
        // exact version is defined by PDClient
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", .suitable),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PDContacts",
            dependencies: [
                .product(name: "ProtonCoreNetworking", package: "protoncore_ios"),
                .product(name: "ProtonCoreServices", package: "protoncore_ios")
            ],
            path: "Sources"
        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
