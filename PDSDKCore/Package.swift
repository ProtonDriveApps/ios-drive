// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
import Foundation

let SDK_PACKAGE: PackageDescription.Package.Dependency = if let localSDKPath = Config().localSDKPath {
    .package(name: "ProtonDriveSDK", path: localSDKPath)
} else {
    /// To use a new release of the SDK:
    ///
    /// Step 1 - Release the new version
    /// a. Go to the pipeline for the commit you want to release
    /// b. Run the "cs:deploy:spm" job - instead if pressing the Play icon, click the name and provide a semver value for the SDK_VERSION variable
    /// c. Find the tag assigned to the new release at https://gitlab.protontech.ch/drive/sdk-swift/-/tags
    /// d. Paste that tag below
    /// e. Rebuild the app
    .package(name: "ProtonDriveSDK",
             url: "https://github.com/ProtonDriveApps/sdk-swift.git",
             branch: "0.15.1")
}

let package = Package(
    name: "PDSDKCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "PDSDKCore", targets: ["PDSDKCore"]),
        .library(name: "PDSDKCoreiOS", targets: ["PDSDKCoreiOS"]),
    ],
    dependencies: [
        .package(name: "PDCore", path: "../PDCore"),
        .package(name: "PDLocalization", path: "../PDLocalization"),
        SDK_PACKAGE,
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs", exact: "9.1.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3") // Same setting from ProtonCore
    ],
    targets: [
        .target(
            name: "PDSDKCore",
            dependencies: [
                .product(name: "ProtonDriveSDK", package: "ProtonDriveSDK"),
                .product(name: "PDCore", package: "PDCore"),
                .product(name: "PDLocalization", package: "PDLocalization"),
            ],
            path: "PDSDKCore"
        ),
        .target(
            name: "PDSDKCoreiOS",
            dependencies: [
                .target(name: "PDSDKCore"),
                .product(name: "PDLocalization", package: "PDLocalization"),
            ],
            path: "PDSDKCoreiOS"
        ),
    ]
)

/// To use a local SDK repo, create a file named "config.json" in this directory, with the following schema:
/// `{ "localSDKPath": String }`
/// NOTE: after changing the `config.json` file, delete Package.resolved and re-run package version resolution.
struct Config: Decodable {
    let localSDKPath: String?

    init() {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(components: "config.json")
        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(Config.self, from: data),
           let localSDKPath = config.localSDKPath,
           !localSDKPath.isEmpty {
            self.localSDKPath = localSDKPath
        } else {
            self.localSDKPath = nil
        }
    }
}
