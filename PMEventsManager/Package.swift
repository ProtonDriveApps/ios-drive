// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PMEventsManager",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)]
    ,
    products: [
        .library(name: "PMEventsManager", targets: ["PMEventsManager"]),
    ],
    dependencies: [

        // exact version is defined by PDClient
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", .suitable),
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

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
