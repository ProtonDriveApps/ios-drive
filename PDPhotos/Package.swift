// swift-tools-version: 5.9.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDPhotos",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "PDPhotos", targets: ["PDPhotos"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", exact: "37.3.0"),
        .package(url: "https://github.com/ProtonMail/apple-fusion.git", exact: "2.1.5"),
        .package(url: "https://github.com/airbnb/lottie-spm", exact: "4.6.0"),
        .package(name: "PDClient", path: "../PDClient"),
        .package(name: "PDCore", path: "../PDCore"),
        .package(name: "PDLocalization", path: "../PDLocalization"),
        .package(name: "PDUIComponents", path: "../PDUIComponents"),
        .package(name: "PDContacts", path: "../PDContacts"),
        .package(name: "PDSDKCore", path: "../PDSDKCore")
    ],
    targets: [
        .target(
            name: "PDPhotos",
            dependencies: [
                .product(name: "ProtonCoreNetworking", package: "protoncore_ios"),
                .product(name: "PDClient", package: "PDClient"),
                .product(name: "PDCore", package: "PDCore"),
                .product(name: "PDCoreIOS", package: "PDCore"),
                .product(name: "PDUIComponents", package: "PDUIComponents"),
                .product(name: "PDLocalization", package: "PDLocalization"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore_ios"),
                .product(name: "PDContacts", package: "PDContacts"),
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "ProtonCoreAuthentication", package: "protoncore_ios"),
                .product(name: "PDSDKCore", package: "PDSDKCore"),
                .product(name: "PDSDKCoreiOS", package: "PDSDKCore")
            ],
            path: "PDPhotos",
            resources: [
                .process("PDPhotosUI/Resources/TagMigrationAnimation.json")
            ]
        ),
    ]
)
