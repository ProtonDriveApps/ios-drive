// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDCore", targets: ["PDCore"]),
    ],
    dependencies: [
        .package(name: "PDClient", path: "../PDClient"),
        .package(name: "PMEventsManager", path: "../PMEventsManager"),
        .package(name: "PDLocalization", path: "../PDLocalization"),

        // exact version is defined by CommonDependencies
        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", .suitable),
        .package(url: "https://github.com/ProtonMail/apple-fusion.git", .suitable),
        .package(url: "https://github.com/ProtonMail/TrustKit.git", .suitable),
    ],
    targets: [
        .target(
            name: "PDCore",
            dependencies: [
                .product(name: "PDClient", package: "PDClient"),
                .product(name: "PMEventsManager", package: "PMEventsManager"),
                .product(name: "PDLocalization", package: "PDLocalization"),

                .product(name: "ProtonCoreLoginUI", package: "protoncore_ios"), // FIXME: !
                .product(name: "ProtonCoreKeyManager", package: "protoncore_ios"),
                .product(name: "ProtonCoreKeymaker", package: "protoncore_ios"),
                .product(name: "ProtonCorePushNotifications", package: "protoncore_ios"),

                .product(name: "TrustKit", package: "TrustKit"),
            ],
            path: "PDCore",
            resources: [
                .process("CoreData/Metadata.xcdatamodeld"),
                .process("EventsProcessor/EventStorageModel.xcdatamodeld"),
                .process("EventsProcessor/Events to Events v1.17.xcmappingmodel"),
                .process("Syncing/SyncModel.xcdatamodeld"),
            ],
            swiftSettings: [
                .define("RESOURCES_ARE_IMPORTED_BY_SPM"),
                .define("INCLUDES_DB_IN_BUGREPORT", .when(configuration: .debug)),
            ]

        ),
    ]
)

extension Range where Bound == Version {
    static let suitable = Self(uncheckedBounds: ("0.0.0", "99.0.0"))
}
