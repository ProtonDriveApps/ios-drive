// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PDCore", targets: ["PDCore"]),
        .library(name: "PDCoreIOS", targets: ["PDCoreIOS"]),
    ],
    dependencies: [
        .package(name: "PDClient", path: "../PDClient"),
        .package(name: "PMEventsManager", path: "../PMEventsManager"),
        .package(name: "PDLocalization", path: "../PDLocalization"),
        .package(name: "PDUIComponents", path: "../PDUIComponents"),
        .package(name: "PDContacts", path: "../PDContacts"),

        .package(url: "https://github.com/ProtonMail/protoncore_ios.git", exact: "37.0.1"),
        .package(url: "https://github.com/ProtonMail/apple-fusion.git", exact: "2.1.5"),
        .package(url: "https://github.com/ProtonMail/TrustKit.git", exact: "1.0.3"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", exact: "5.2.4"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20"),
    ],
    targets: [
        .target(
            name: "PDCore",
            dependencies: [
                .product(name: "PDClient", package: "PDClient"),
                .product(name: "PMEventsManager", package: "PMEventsManager"),
                .product(name: "PDLocalization", package: "PDLocalization"),

                .product(name: "ProtonCoreAuthentication", package: "protoncore_ios"),
                .product(name: "ProtonCoreAPIClient", package: "protoncore_ios"),
                .product(name: "ProtonCoreChallenge", package: "protoncore_ios", condition: .when(platforms: [.iOS])),
                .product(name: "ProtonCoreCrypto", package: "protoncore_ios"),
                .product(name: "ProtonCoreCryptoGoInterface", package: "protoncore_ios"),
                .product(name: "ProtonCoreDataModel", package: "protoncore_ios"),
                .product(name: "ProtonCoreEnvironment", package: "protoncore_ios"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore_ios"),
                .product(name: "ProtonCoreKeyManager", package: "protoncore_ios"),
                .product(name: "ProtonCoreKeymaker", package: "protoncore_ios"),
                .product(name: "ProtonCoreNetworking", package: "protoncore_ios"),
                .product(name: "ProtonCoreObservability", package: "protoncore_ios"),
                .product(name: "ProtonCorePayments", package: "protoncore_ios"),
                .product(name: "ProtonCorePushNotifications", package: "protoncore_ios"),
                .product(name: "ProtonCoreServices", package: "protoncore_ios"),
                .product(name: "ProtonCoreTelemetry", package: "protoncore_ios"),
                .product(name: "ProtonCoreUtilities", package: "protoncore_ios"),

                .product(name: "Reachability", package: "Reachability.swift"),
                .product(name: "TrustKit", package: "TrustKit"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "PDCore",
            resources: [
                .process("CoreData/Metadata.xcdatamodeld"),
                .process("EventsProcessor/Storage/Events/EventStorageModel.xcdatamodeld"),
                .process("EventsProcessor/Storage/Events/Events to Events v1.17.xcmappingmodel"),
                .process("Syncing/SyncModel.xcdatamodeld"),
            ],
            swiftSettings: [
                .define("RESOURCES_ARE_IMPORTED_BY_SPM"),
                .define("INCLUDES_DB_IN_BUGREPORT", .when(configuration: .debug)),
            ]

        ),
        .target(
            name: "PDCoreIOS",
            dependencies: [
                .target(name: "PDCore"),
                .product(name: "PDUIComponents", package: "PDUIComponents"),
                .product(name: "PDContacts", package: "PDContacts"),
                .product(name: "ProtonCorePaymentsUI", package: "protoncore_ios"),
                .product(name: "ProtonCorePaymentsV2", package: "protoncore_ios"),
                .product(name: "ProtonCorePaymentsUIV2", package: "protoncore_ios"),
            ],
            path: "PDCoreIOS"
        ),
    ]
)
