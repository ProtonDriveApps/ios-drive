// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation
import os.log
import PDClient
import PDCore
import FileProvider
import ProtonCoreEnvironment

enum Constants: LogObject {
    static var osLog: OSLog = OSLog(subsystem: "ch.protondrive", category: "AppLevel")
    
    // MARK: - Environments
    enum SettingsBundleKeys: String {
        case host = "DEFAULT_API_HOST"
        
        case appStorePageURL = "APPSTORE_PAGE_LINK"
        case appVersionIdentifier = "APP_VERSION_IDENTIFIER"
        case photosReminderDelay = "DEFAULT_PHOTOS_REMINDER_DELAY"
        case uploadedPhotoNotification = "UPLOADED_PHOTO_NOTIFICATION"
    }
    
    static let appGroup: SettingsStorageSuite = .group(named: "group.ch.protonmail.protondrive")
    static let clientApiConfig = loadConfiguration()

    // MARK: - Pagination
    static var childrenRefreshStrategy: RefreshMode {
        PDCore.Constants.childrenRefreshStrategy
    }
    
    // MARK: - Features
    static let isStoreKitReady: Bool = false         // removes "Upgrade" button in menu Storage section
    private(set) static var hasPhotosReminderStandardDelay = loadHasPhotosReminderStandardDelay()
    private(set) static var uploadedPhotoNotification = loadUploadedPhotoNotification()

    // MARK: - Internal
    static let highStorageUsageRatio: Double = 0.9  // switches menu Storage section into "red" mode
    static let maxNumberOfFailedUnlockAttempts: Int = 10

    // MARK: - Report a Bug
    static let reportBugURL = URL(string: "https://protonmail.com/support-form")!
    
    // MARK: - Force Upgrade
    static let appStorePageURL = URL(string: loadSettingValue(for: .appStorePageURL)) ?? reportBugURL
    static let forceUpgradeLearnMoreURL = URL(string: "https://protonmail.com/support/knowledge-base/update-required") ?? reportBugURL
    
    // MARK: - IAP (StoreKit Product IDs)
    static let oneDollarPlanDefaultPrice = "$0.99"
    static let oneDollarPlanID = "iosdrive_drivelite2024_1_usd_auto_renewing"
    
    static let drivePlanIDs: Set<String> = [
        "iosdrive_drive2022_12_usd_non_renewing",
        "iosdrive_bundle2022_12_usd_non_renewing",
    ]
    
    static let shownPlanNames: Set<String> = [
        "drive2022",
        "bundle2022",
        "drivepro2022",
        "family2022",
        "visionary2022",
        "bundlepro2022",
        "enterprise2022",
    ]
    
    // MARK: - Background mode
    static let backgroundTaskIdentifier = "ch.protonmail.protondrive.processing"
    static let checkNewPhotoInGallery = "ch.protonmail.checkNewPhotoInGallery"

    // MARK: - Photos
    static let photosAssetsParallelProcessingCount = 1
    static let photosLibraryProcessingBatchSize = 20
    static let photosUploaderParallelProcessingCount = 2
    static let photosAssetsMaximalFolderSize = 200_000_000 // bytes count
    static let minimalSpaceForAllowingUpload = 25 * 1024 * 1024 // bytes count
    static let photosNecessaryFreeStorage = 2_000_000_000 // Space needed to proceed with photos backup. Bytes count. Arbitrary number.
    static let photosPlaceholderAssetName = "emptyName" // Name seems to be empty for assets coming from `PHAssetSourceType.typeiTunesSynced`. We need to return some name, otherwise the process fails.

    // MARK: - Telemetry constants
    enum Metrics {
        static let photosBackupHeartbeatInterval: Double = 15 * 60 // 15 minutes
    }
}

extension Constants {
    
    /// Conforms to https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions
    /// Configuration            App                                                         FileProvider
    ///
    /// Debug                  |    ios-drive@1.3.2-dev               |    ios-drive-fileprovider@1.3.2-dev
    /// Release-QA         |    ios-drive@1.3.2-dev+4379    |    ios-drive-fileprovider@1.3.2-dev+4379
    /// Release-External |    ios-drive@1.3.2-beta+4379  |    ios-drive-fileprovider@1.3.2-beta+4379
    /// Release-Store      |    ios-drive@1.3.2+4379             |    ios-drive-fileprovider@1.3.2+4379
    ///
    private static let clientVersion: String = {
        guard let info = Bundle.main.infoDictionary else {
            return "ios-drive@0.0.0"
        }

        var appVersion = "ios-drive"
        if PDCore.Constants.runningInExtension {
            appVersion += "-fileprovider"
        }
        
        // MAJOR.MINOR.PATCH, all digits
        let version = (info["CFBundleShortVersionString"] as! String)
        appVersion += "@" + version

        // dev, alpha, beta, etc
        let identifier = loadSettingValue(for: .appVersionIdentifier)
        if !identifier.isEmpty {
            appVersion += "-\(identifier)"
        }

        // Debug or NUMBER.CONFIG, all digits
        let build = info["CFBundleVersion"] as! String
        if build.lowercased() != "debug" {
            let buildWithoutSuffix = build.components(separatedBy: ".").first ?? ""
            appVersion += "+\(buildWithoutSuffix)"
        }

        return appVersion
    }()
    
    private static func loadSettingValue(for key: SettingsBundleKeys) -> String {
        #if HAS_QA_FEATURES
        // values should be placed in shared UserDefaults so appex will be able to read them
        let sharedUserDefaults = UserDefaults(suiteName: "group.ch.protonmail.protondrive")
        if let modifiedValue = sharedUserDefaults?.value(forKey: key.rawValue) as? String, !modifiedValue.isEmpty {
            return modifiedValue
        } 
        #endif
        
        if let defaultValue = Bundle.main.infoDictionary?[key.rawValue] as? String {
            return defaultValue
        } else {
            assert(false, "No value was defined for \(key.rawValue)")
            return ""
        }
    }

    private static func loadSettingsValue<T>(for key: SettingsBundleKeys) -> T {
        #if HAS_QA_FEATURES
        // values should be placed in shared UserDefaults so appex will be able to read them
        let sharedUserDefaults = UserDefaults(suiteName: "group.ch.protonmail.protondrive")
        if let modifiedValue = sharedUserDefaults?.value(forKey: key.rawValue) as? T {
            return modifiedValue
        }
        #endif
        
        if let defaultValue = Bundle.main.infoDictionary?[key.rawValue] as? T {
            return defaultValue
        } else {
            fatalError("No value was defined for \(key.rawValue)")
        }
    }

    private static func loadConfiguration() -> APIService.Configuration {
        #if DEBUG
        if let dynamicDomain = dynamicDomain, isUITest {
            return Configuration(environment: .custom(dynamicDomain), clientVersion: clientVersion)
        } else {
            return loadConfigurationFromSettingsBundle()
        }
        #else
        return loadConfigurationFromSettingsBundle()
        #endif
    }
    
    private static func loadConfigurationFromSettingsBundle() -> APIService.Configuration {
        var environment = Environment.driveProd

        #if HAS_QA_FEATURES
        let host = loadSettingValue(for: .host)
        switch host {
        case "proton.black", "drive.proton.black":
            environment = .black
        case "payments.proton.black":
            environment = .blackPayment
        case let scientist where scientist.hasSuffix(".black"): // scientists only
            environment = .custom(host)
        default:
            break
        }
        #endif
        
        #if NO_DOH
        switch environment {
        case .driveProd, .black, .blackPayment:
            environment.updateDohStatus(to: .off)
        default:
            break
        }
        #endif
        
        return Configuration(environment: environment, clientVersion: clientVersion)
    }

    static var isUITest: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitests") {
            return true
        }

        if let environmentVar = Bundle.main.infoDictionary?["IS_UI_TEST"] as? String,
           let flag = Bool(environmentVar) {
            // Bool(_ description: String) only accepts "true" or "false", case sensitive
            return flag
        }
        #endif
        return false
    }

    private static var dynamicDomain: String? {
        if let domain = Bundle.main.infoDictionary?["DYNAMIC_DOMAIN"] as? String, !domain.isEmpty {
            persistDynamicDomainIfNeeded(domain)
            return domain
        } else {
            return nil
        }
    }

    private static func loadHasPhotosReminderStandardDelay() -> Bool {
        #if HAS_QA_FEATURES
            return loadSettingsValue(for: .photosReminderDelay)
        #else
            return true
        #endif
    }

    private static func loadUploadedPhotoNotification() -> Bool {
        #if HAS_QA_FEATURES
            return Constants.isUITest || loadSettingsValue(for: .uploadedPhotoNotification)
        #else
            return false
        #endif
    }
    
    private static func persistDynamicDomainIfNeeded(_ domain: String) {
        guard ProcessInfo.processInfo.arguments.contains("--persist_dynamic_domain") else {
            return
        }
        
        let sharedUserDefaults = UserDefaults(suiteName: "group.ch.protonmail.protondrive")
        sharedUserDefaults?.set(domain, forKey: SettingsBundleKeys.host.rawValue)
    }
}
