// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PMSideMenu",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "PMSideMenu", targets: ["PMSideMenu"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kukushi/SideMenu.git", exact: "2.1.1"),
    ],
    targets: [
        .target(
            name: "PMSideMenu",
            dependencies: [
                .product(name: "SideMenu", package: "SideMenu"),
            ],
            path: "Sources/PMSideMenu"
        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
