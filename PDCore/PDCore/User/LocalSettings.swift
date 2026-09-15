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
import PDClient

public class LocalSettings: NSObject {
    let featureFlagCatalog = FeatureFlagCatalog()

    @SettingsStorage("computersInitialLoad") public var computersInitialLoad: Bool?
    @SettingsStorage("sortPreferenceCache") private var sortPreferenceCache: SortPreference.RawValue?
    @SettingsStorage("layoutPreferenceCache") private var layoutPreferenceCache: LayoutPreference.RawValue?
    @SettingsStorage("invitationSortPreference") private var invitationSortPreferenceCache: InvitationSortPreference.RawValue?
    @SettingsStorage("isUploadingDisclaimerActiveValue") private var isUploadingDisclaimerActiveValue: Bool?
    @SettingsStorage("isOnboarded") private var isOnboardedValue: Bool?
    @SettingsStorage("upsellShownValue") private var isUpsellShownValue: Bool?
    @SettingsStorage("isPhotoUpsellShownValue") private var isPhotoUpsellShownValue: Bool?
    @SettingsStorage("showPhotoUpsellInNextLaunch") public var showPhotoUpsellInNextLaunch: Bool?
    @SettingsStorage("didFetchFeatureFlags") public var didFetchFeatureFlags: Bool?

    @SettingsStorage("optOutFromTelemetry") var optOutFromTelemetry: Bool?
    @SettingsStorage("optOutFromCrashReports") var optOutFromCrashReports: Bool?
    @SettingsStorage("userId") public var userId: String?
    @SettingsStorage("isNoticationPermissionsSkipped") public var isNoticationPermissionsSkipped: Bool?
    @SettingsStorage("isPhotosBackupEnabledValue") private(set) var isPhotosBackupEnabledValue: Bool?
    @SettingsStorage("isPhotosBackupConnectionConstrainedValue") private(set) var isPhotosBackupConnectionConstrainedValue: Bool?
    @SettingsStorage("isPhotosNotificationsPermissionsSkipped") public var isPhotosNotificationsPermissionsSkipped: Bool?
    @SettingsStorage("isPhotosMediaTypeImageSupportedValue") private(set) var isPhotosMediaTypeImageSupportedValue: Bool?
    @SettingsStorage("isPhotosMediaTypeVideoSupportedValue") private(set) var isPhotosMediaTypeVideoSupportedValue: Bool?
    @SettingsStorage("isPhotoTagsAnalysisDisabledValue") private(set) var isPhotoTagsAnalysisDisabledValue: Bool?
    @SettingsStorage("isEXIFUploadingDisabledValue") private(set) var isEXIFUploadingDisabledValue: Bool?
    @SettingsStorage("photosBackupNotOlderThanValue") private(set) var photosBackupNotOlderThanValue: Date?
    @SettingsStorage("defaultHomeTabIndex") private(set) var defaultHomeTabTagValue: Int?
    @SettingsStorage("didShowPhotosNotification") public var didShowPhotosNotification: Bool?

    @SettingsStorage("promotedNewFeaturesValue") var promotedNewFeaturesValue: [String]?

    @SettingsStorage("debugModeEnabledValue") public var debugModeEnabledValue: Bool?
    @SettingsStorage("keepScreenAwakeBannerHasDismissed") public var keepScreenAwakeBannerHasDismissed: Bool?
    @SettingsStorage("didShowEditorPermissionsTooltip") public var didShowEditorPermissionsTooltip: Bool?
    @SettingsStorage("photoVolumeMigrationLastShownDate") public var photoVolumeMigrationLastShownDate: Date?
    @SettingsStorage("QuotaState") public var quotaStateValue: Int?

    @SettingsStorage("tagsMigrationFinished") var tagsMigrationFinishedValue: Bool?
    @SettingsStorage("isTagsMigrationSheetShownValue") private var isTagsMigrationSheetShownValue: Bool?

    // Photo tab for b2b user
    @SettingsStorage("IsB2BUserValue") public var isB2BUserValue: Bool?

    @SettingsStorage("DriveEntitlements") public var driveEntitlementsValue: Data?
    @SettingsStorage("DriveEntitlementsUpdatedTime") public var driveEntitlementsUpdatedTimeValue: Int64?

    // Checklist
    @SettingsStorage("driveChecklistStatusDataValue") private var driveChecklistStatusDataValue: Data?
    // ⚠️ Disclaimer: when adding new `@SettingsStorage` variable, make sure you configure its suite in initializer.

    // drive/me/settings
    @SettingsStorage("Layout") public var layout: Int?
    @SettingsStorage("Sort") public var sort: Int?
    @SettingsStorage("RevisionRetentionDays") public var revisionRetentionDays: Int?
    @SettingsStorage("B2BPhotosEnabled") public var b2bPhotosEnabled: Bool?
    @SettingsStorage("DocsCommentsNotificationsEnabled") public var docsCommentsNotificationsEnabled: Bool?
    @SettingsStorage("DocsCommentsNotificationsIncludeDocumentName") public var docsCommentsNotificationsIncludeDocumentName: Bool?
    @SettingsStorage("PhotoTags") public var photoTags: [Int]?
    // Settings Flags
    @SettingsStorage("didFetchDriveUserSettings") public var didFetchDriveUserSettings: Bool?
    @SettingsStorage("didFetchProtonUserSettings") public var didFetchProtonUserSettings: Bool?
    @SettingsStorage("didFetchB2BStatus") public var didFetchB2BStatus: Bool?
    public var enableDebugModeInThisLaunch: Bool = false

    // Upgrade requirement
    /// The app version from the previous launch
    @SettingsStorage("PreviousAppVersion") private var previousAppVersionValue: String?
    /// Whether the upgrade hint banner should be displayed
    @SettingsStorage("UpgradeRequirementResultValue") private var upgradeRequirementResultValue: Data?
    /// User has dismissed upgrade recommend banner
    @SettingsStorage("HasDismissedUpgradeBanner") private var hasDismissedUpgradeBannerValue: Bool?
    /// Locked volume lock banner skipped for these share IDs, for iOS
    @SettingsStorage("SkippedVolumeLockShareIDs") private var skippedVolumeLockShareIDsValue: [String]?
    // - MARK: Experience feature
    @SettingsStorage("iOSRefactoredFinder") private var iOSRefactoredFinderValue: Bool?

    public let suite: SettingsStorageSuite

    public init(suite: SettingsStorageSuite) {
        self.suite = suite
        super.init()
        self._computersInitialLoad.configure(with: suite)
        self._sortPreferenceCache.configure(with: suite)
        self._layoutPreferenceCache.configure(with: suite)
        self._invitationSortPreferenceCache.configure(with: suite)
        self._optOutFromTelemetry.configure(with: suite)
        self._optOutFromCrashReports.configure(with: suite)
        self._isOnboardedValue.configure(with: suite)
        self._isUpsellShownValue.configure(with: suite)
        self._isPhotoUpsellShownValue.configure(with: suite)
        self._showPhotoUpsellInNextLaunch.configure(with: suite)
        self._isUploadingDisclaimerActiveValue.configure(with: suite)
        self._isNoticationPermissionsSkipped.configure(with: suite)
        self._isPhotosBackupEnabledValue.configure(with: suite)
        self._isPhotosBackupConnectionConstrainedValue.configure(with: suite)
        self._isPhotosNotificationsPermissionsSkipped.configure(with: suite)
        self._isPhotosMediaTypeImageSupportedValue.configure(with: suite)
        self._isPhotosMediaTypeVideoSupportedValue.configure(with: suite)
        self._isPhotoTagsAnalysisDisabledValue.configure(with: suite)
        self._isEXIFUploadingDisabledValue.configure(with: suite)
        self._photosBackupNotOlderThanValue.configure(with: suite)
        self._debugModeEnabledValue.configure(with: suite)
        self._userId.configure(with: suite)
        self._defaultHomeTabTagValue.configure(with: suite)
        self._keepScreenAwakeBannerHasDismissed.configure(with: suite)
        self._didShowEditorPermissionsTooltip.configure(with: suite)
        self._didFetchFeatureFlags.configure(with: suite)
        self._promotedNewFeaturesValue.configure(with: suite)
        self._photoVolumeMigrationLastShownDate.configure(with: suite)
        self._quotaStateValue.configure(with: suite)
        self._tagsMigrationFinishedValue.configure(with: suite)
        self._isTagsMigrationSheetShownValue.configure(with: suite)
        self._iOSRefactoredFinderValue.configure(with: suite)

        // Photo tab for b2b user
        self._isB2BUserValue.configure(with: suite)
        // Drive entitlements
        self._driveEntitlementsValue.configure(with: suite)
        self._driveEntitlementsUpdatedTimeValue.configure(with: suite)

        featureFlagCatalog.configure(with: suite)

        if let sortPreferenceCache = self.sortPreferenceCache {
            nodesSortPreference = SortPreference(rawValue: sortPreferenceCache) ?? SortPreference.default
        } else {
            nodesSortPreference = SortPreference.default
        }
        self._driveChecklistStatusDataValue.configure(with: suite)
        // drive/me/settings
        self._layout.configure(with: suite)
        self._sort.configure(with: suite)
        self._revisionRetentionDays.configure(with: suite)
        self._b2bPhotosEnabled.configure(with: suite)
        self._docsCommentsNotificationsEnabled.configure(with: suite)
        self._docsCommentsNotificationsIncludeDocumentName.configure(with: suite)
        self._photoTags.configure(with: suite)

        // Settings Flags
        self._didFetchDriveUserSettings.configure(with: suite)
        self._didFetchProtonUserSettings.configure(with: suite)
        self._didFetchB2BStatus.configure(with: suite)

        // Upgrade requirement
        self._previousAppVersionValue.configure(with: suite)
        self._upgradeRequirementResultValue.configure(with: suite)
        self._hasDismissedUpgradeBannerValue.configure(with: suite)
        self._skippedVolumeLockShareIDsValue.configure(with: suite)

        setDynamicVariables()
    }

    /// KVO compliant dynamic variables need to be set individually after initialization / cleanup
    private func setDynamicVariables() {
        nodesLayoutPreference = LayoutPreference(cachedValue: layoutPreferenceCache)
        isUploadingDisclaimerActive = isUploadingDisclaimerActiveValue ?? true
        isPhotosBackupEnabled = isPhotosBackupEnabledValue ?? false
        isPhotosBackupConnectionConstrained = isPhotosBackupConnectionConstrainedValue ?? true
        isPhotosMediaTypeImageSupported = isPhotosMediaTypeImageSupportedValue ?? true
        isPhotosMediaTypeVideoSupported = isPhotosMediaTypeVideoSupportedValue ?? true
        isPhotoTagsAnalysisDisabled = isPhotoTagsAnalysisDisabledValue ?? false
        isEXIFUploadingDisabled = isEXIFUploadingDisabledValue ?? false
        photosBackupNotOlderThan = photosBackupNotOlderThanValue ?? .distantPast
        photosUploadDisabled = featureFlagCatalog.photosUploadDisabled
        logsCompressionDisabled = featureFlagCatalog.logsCompressionDisabled
        debugModeEnabled = debugModeEnabledValue ?? false
        domainReconnectionEnabled = featureFlagCatalog.domainReconnectionEnabled
        postMigrationJunkFilesCleanup = featureFlagCatalog.postMigrationJunkFilesCleanup
        oneDollarPlanUpsellEnabled = featureFlagCatalog.oneDollarPlanUpsellEnabled
        isOnboarded = isOnboardedValue ?? false
        isB2BUser = isB2BUserValue ?? false
        pushNotificationIsEnabled = featureFlagCatalog.pushNotificationIsEnabled
        if let value = defaultHomeTabTagValue {
            defaultHomeTabTag = value
        }
        driveSharingMigration = featureFlagCatalog.driveSharingMigration
        driveSharingExternalInvitations = featureFlagCatalog.driveSharingExternalInvitations
        driveSharingDisabled = featureFlagCatalog.driveSharingDisabled
        driveSharingExternalInvitationsDisabled = featureFlagCatalog.driveSharingExternalInvitationsDisabled
        drivePublicShareEditMode = featureFlagCatalog.drivePublicShareEditMode
        driveShareURLBookmarking = featureFlagCatalog.driveShareURLBookmarking
        driveShareURLBookmarksDisabled = featureFlagCatalog.driveShareURLBookmarksDisabled
        drivePublicShareEditModeDisabled = featureFlagCatalog.drivePublicShareEditModeDisabled
        driveDisablePhotosForB2B = featureFlagCatalog.driveDisablePhotosForB2B
        driveMacFullResyncAlwaysVisibleDisabled = featureFlagCatalog.driveMacFullResyncAlwaysVisibleDisabled
        docsSheetsEnabled = featureFlagCatalog.docsSheetsEnabled
        docsSheetsDisabled = featureFlagCatalog.docsSheetsDisabled
        docsCreateNewSheetOnMobileEnabled = featureFlagCatalog.docsCreateNewSheetOnMobileEnabled

        // drive/me/settings
        self.driveSettingsLayout = LayoutPreference(forcedFromValue: layout)
        self.driveSettingsSort = sort ?? 0
        self.driveSettingsRevisionRetentionDays = revisionRetentionDays ?? 180
        self.driveSettingsB2BPhotosEnabled = b2bPhotosEnabled ?? false
        self.driveSettingsDocsCommentsNotificationsEnabled = docsCommentsNotificationsEnabled ?? false
        self.driveSettingsDocsCommentsNotificationsIncludeDocumentName = docsCommentsNotificationsIncludeDocumentName ?? false
        self.driveSettingsPhotoTags = photoTags ?? [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        // SDK
        driveiOSSDKNodeOperations = featureFlagCatalog.driveiOSSDKNodeOperations
        driveCryptoEncryptBlocksWithPgpAead = featureFlagCatalog.driveCryptoEncryptBlocksWithPgpAead
        driveMacFileProviderBatchingDisabled = featureFlagCatalog.driveMacFileProviderBatchingDisabled
        driveDownloadVerificationDisabled = featureFlagCatalog.driveDownloadVerificationDisabled
        driveUploadVerificationDisabled = featureFlagCatalog.driveUploadVerificationDisabled
    }

    /// `cleanUserSpecificSettings`
    ///     - true if we want to clean everything
    ///     - false if we want to keep flags related to the user
    ///     Used to differentiate signout and clean cache - signout should wipe everything,
    ///     clean cache only real "cache" item
    public func cleanUp(cleanUserSpecificSettings: Bool = true) {
        self.computersInitialLoad = nil
        self.sortPreferenceCache = nil
        self.layoutPreferenceCache = nil
        self.invitationSortPreferenceCache = nil
        self.optOutFromTelemetry = nil
        self.optOutFromCrashReports = nil
        self.userId = nil
        self.didFetchFeatureFlags = nil
        // self.isOnboardedValue needs no clean up - we only show it for first login ever
        // self.isUpsellShownValue needs no clean up - we only show it once
        // self.isPhotoUpsellShownValue needs no clean up - we only show it once
        self.isUploadingDisclaimerActiveValue = nil
        self.isNoticationPermissionsSkipped = nil
        self.isPhotosBackupEnabledValue = nil
        self.isPhotosBackupConnectionConstrainedValue = nil
        self.isPhotosNotificationsPermissionsSkipped = nil
        self.isPhotosMediaTypeImageSupportedValue = nil
        self.isPhotosMediaTypeVideoSupportedValue = nil
        self.isPhotoTagsAnalysisDisabledValue = nil
        self.isEXIFUploadingDisabledValue = nil
        self.debugModeEnabledValue = nil
        featureFlagCatalog.cleanUp(cleanUserSpecificSettings: cleanUserSpecificSettings)
        self.keepScreenAwakeBannerHasDismissed = nil
        self.didShowEditorPermissionsTooltip = nil
        self.didShowPhotosNotification = nil
        self.isB2BUserValue = nil
        self.showPhotoUpsellInNextLaunch = nil
        self.driveEntitlementsValue = nil
        self.driveEntitlementsUpdatedTimeValue = nil
        if cleanUserSpecificSettings {
            promotedNewFeaturesValue = nil
            quotaStateValue = nil
            self.defaultHomeTabTagValue = 1
            self.didFetchB2BStatus = nil
            isTagsMigrationSheetShownValue = nil
            skippedVolumeLockShareIDsValue = nil
            iOSRefactoredFinderValue = nil
        }
        photoVolumeMigrationLastShownDate = nil
        driveChecklistStatusDataValue = nil
        tagsMigrationFinishedValue = nil
        self.layout = nil
        self.sort = nil
        self.revisionRetentionDays = nil
        self.b2bPhotosEnabled = nil
        self.docsCommentsNotificationsEnabled = nil
        self.docsCommentsNotificationsIncludeDocumentName = nil
        self.photoTags = nil
        self.didFetchDriveUserSettings = nil
        self.didFetchProtonUserSettings = nil
        // previousAppVersionValue and upgradeRequirementResultValue are intentionally preserved,
        // as they should remain the same after clearing the cache or signing in again
        self.hasDismissedUpgradeBannerValue = nil
        setDynamicVariables()
    }

    public var photosUploadDisabledValue: Bool? {
        get { featureFlagCatalog.photosUploadDisabled }
        set {
            if let newValue {
                featureFlagCatalog.photosUploadDisabled = newValue
            } else {
                featureFlagCatalog.clear([.photosUploadDisabled])
            }
        }
    }

    public var driveMobileUpsellPlanPayload: String? {
        get { featureFlagCatalog.driveMobileUpsellPlanPayload }
        set { featureFlagCatalog.driveMobileUpsellPlanPayload = newValue }
    }

    @objc public dynamic var nodesSortPreference: SortPreference = SortPreference.default {
        willSet {
            self.sortPreferenceCache = newValue.rawValue
        }
    }

    @objc public dynamic var nodesLayoutPreference: LayoutPreference = LayoutPreference.default {
        willSet {
            self.layoutPreferenceCache = newValue.rawValue
        }
    }

    @objc public dynamic var invitationSortPreference: InvitationSortPreference = InvitationSortPreference.default {
        willSet {
            self.invitationSortPreferenceCache = newValue.rawValue
        }
    }

    @objc public dynamic var isUploadingDisclaimerActive: Bool = true {
        willSet {
            isUploadingDisclaimerActiveValue = newValue
        }
    }

    @objc public dynamic var isPhotosBackupEnabled: Bool = false {
        willSet {
            isPhotosBackupEnabledValue = newValue
        }
    }

    @objc public dynamic var isPhotosBackupConnectionConstrained: Bool = true {
        willSet {
            isPhotosBackupConnectionConstrainedValue = newValue
        }
    }

    @objc public dynamic var isPhotosMediaTypeImageSupported: Bool = true {
        willSet {
            isPhotosMediaTypeImageSupportedValue = newValue
        }
    }

    @objc public dynamic var isPhotosMediaTypeVideoSupported: Bool = true {
        willSet {
            isPhotosMediaTypeVideoSupportedValue = newValue
        }
    }

    @objc public dynamic var isPhotoTagsAnalysisDisabled: Bool = false {
        willSet {
            isPhotoTagsAnalysisDisabledValue = newValue
        }
    }

    @objc public dynamic var isEXIFUploadingDisabled: Bool = false {
        willSet {
            isEXIFUploadingDisabledValue = newValue
        }
    }

    @objc public dynamic var photosBackupNotOlderThan: Date = .distantPast {
        willSet {
            photosBackupNotOlderThanValue = newValue
        }
    }

    @objc public dynamic var photosUploadDisabled: Bool = false {
        willSet {
            featureFlagCatalog.photosUploadDisabled = newValue
        }
    }

    @objc public dynamic var logsCompressionDisabled: Bool = false {
        willSet {
            featureFlagCatalog.logsCompressionDisabled = newValue
        }
    }

    @objc public dynamic var domainReconnectionEnabled: Bool = false {
        willSet {
            featureFlagCatalog.domainReconnectionEnabled = newValue
        }
    }

    @objc public dynamic var postMigrationJunkFilesCleanup: Bool = false {
        willSet {
            featureFlagCatalog.postMigrationJunkFilesCleanup = newValue
        }
    }

    @objc public dynamic var oneDollarPlanUpsellEnabled: Bool = false {
        willSet {
            featureFlagCatalog.oneDollarPlanUpsellEnabled = newValue
        }
    }

    @objc public dynamic var isOnboarded: Bool = false {
        willSet {
            isOnboardedValue = newValue ? true : nil
        }
    }

    @objc public dynamic var pushNotificationIsEnabled: Bool = false {
        willSet {
            featureFlagCatalog.pushNotificationIsEnabled = newValue
        }
    }

    public var driveiOSDebugMode: Bool {
        get { featureFlagCatalog.driveiOSDebugMode }
        set { featureFlagCatalog.driveiOSDebugMode = newValue }
    }

    public var driveiOSPaymentsV2: Bool {
        get { featureFlagCatalog.driveiOSPaymentsV2 }
        set { featureFlagCatalog.driveiOSPaymentsV2 = newValue }
    }

    public var driveMobileUpsellPlan: Bool {
        get { featureFlagCatalog.driveMobileUpsellPlan }
        set { featureFlagCatalog.driveMobileUpsellPlan = newValue }
    }

    @objc public dynamic var defaultHomeTabTag: Int = 1 {
        willSet {
            defaultHomeTabTagValue = newValue
        }
    }

    @objc public dynamic var isUpsellShown: Bool {
        get { isUpsellShownValue == true }
        set { isUpsellShownValue = (newValue ? true : nil) }
    }

    @objc public dynamic var debugModeEnabled: Bool = false {
        willSet {
            debugModeEnabledValue = newValue
        }
    }

    public var promotedNewFeatures: [String] {
        promotedNewFeaturesValue ?? []
    }

    public func append(promotedNewFeatures: [String]) {
        let features = promotedNewFeaturesValue ?? []
        promotedNewFeaturesValue = Array(Set(features.appending(promotedNewFeatures)))
    }

    public var skippedVolumeLockShareIDs: [String] {
        skippedVolumeLockShareIDsValue ?? []
    }

    public func skipVolumeLockShares(withIDs shareIDs: [String]) {
        let merged = Array(Set(skippedVolumeLockShareIDs + shareIDs)).sorted()
        skippedVolumeLockShareIDsValue = merged.isEmpty ? nil : merged
    }

    // MARK: - Sharing
    @objc public dynamic var driveSharingMigration: Bool = false {
        willSet { featureFlagCatalog.driveSharingMigration = newValue }
    }

    @objc public dynamic var driveSharingExternalInvitations: Bool = false {
        willSet { featureFlagCatalog.driveSharingExternalInvitations = newValue }
    }

    @objc public dynamic var driveSharingDisabled: Bool = false {
        willSet { featureFlagCatalog.driveSharingDisabled = newValue }
    }

    @objc public dynamic var driveSharingExternalInvitationsDisabled: Bool = false {
        willSet { featureFlagCatalog.driveSharingExternalInvitationsDisabled = newValue }
    }

    @objc public dynamic var drivePublicShareEditMode: Bool = false {
        willSet { featureFlagCatalog.drivePublicShareEditMode = newValue }
    }

    @objc public dynamic var driveShareURLBookmarking: Bool = false {
        willSet { featureFlagCatalog.driveShareURLBookmarking = newValue }
    }

    @objc public dynamic var driveShareURLBookmarksDisabled: Bool = false {
        willSet { featureFlagCatalog.driveShareURLBookmarksDisabled = newValue }
    }

    @objc public dynamic var drivePublicShareEditModeDisabled: Bool = false {
        willSet { featureFlagCatalog.drivePublicShareEditModeDisabled = newValue }
    }

    @objc public dynamic var isB2BUser: Bool {
        get { isB2BUserValue ?? false }
        set { isB2BUserValue = newValue }
    }

    public var isPhotoUpsellShown: Bool {
        get { isPhotoUpsellShownValue ?? false }
        set { isPhotoUpsellShownValue = (newValue ? true : nil) }
    }

    @objc public dynamic var driveDisablePhotosForB2B: Bool = false {
        willSet { featureFlagCatalog.driveDisablePhotosForB2B = newValue }
    }

    public var driveMacFullResyncAlwaysVisibleDisabled: Bool {
        get { featureFlagCatalog.driveMacFullResyncAlwaysVisibleDisabled }
        set { featureFlagCatalog.driveMacFullResyncAlwaysVisibleDisabled = newValue }
    }

    public var driveMacPromoBannerDisabled: Bool {
        get { featureFlagCatalog.driveMacPromoBannerDisabled }
        set { featureFlagCatalog.driveMacPromoBannerDisabled = newValue }
    }

    public var driveMacGradualRolloutChannelEnabled: Bool {
        get { featureFlagCatalog.driveMacGradualRolloutChannelEnabled }
        set { featureFlagCatalog.driveMacGradualRolloutChannelEnabled = newValue }
    }

    public var driveMacAbnormalExitRelaunchDisabled: Bool {
        get { featureFlagCatalog.driveMacAbnormalExitRelaunchDisabled }
        set { featureFlagCatalog.driveMacAbnormalExitRelaunchDisabled = newValue }
    }

    public var ratingIOSDrive: Bool {
        get { featureFlagCatalog.ratingIOSDrive }
        set { featureFlagCatalog.ratingIOSDrive = newValue }
    }

    public var driveRatingBooster: Bool {
        get { featureFlagCatalog.driveRatingBooster }
        set { featureFlagCatalog.driveRatingBooster = newValue }
    }

    public var driveDynamicEntitlementConfiguration: Bool {
        get { featureFlagCatalog.driveDynamicEntitlementConfiguration }
        set { featureFlagCatalog.driveDynamicEntitlementConfiguration = newValue }
    }

    public var driveCopyDisabled: Bool {
        get { featureFlagCatalog.driveCopyDisabled }
        set { featureFlagCatalog.driveCopyDisabled = newValue }
    }

    // If there is no data about the checklist status, return empty data that will be interpreted as not available.
    @objc public dynamic var driveChecklistStatusData: Data {
        get { driveChecklistStatusDataValue ?? Data() }
        set { driveChecklistStatusDataValue = newValue }
    }

    public var drivePhotosTagsMigrationDisabled: Bool {
        get { featureFlagCatalog.drivePhotosTagsMigrationDisabled }
        set { featureFlagCatalog.drivePhotosTagsMigrationDisabled = newValue }
    }

    @objc public dynamic var tagsMigrationFinished: Bool {
        get { tagsMigrationFinishedValue ?? false }
        set { tagsMigrationFinishedValue = newValue }
    }

    public var isTagsMigrationSheetShown: Bool {
        get { isTagsMigrationSheetShownValue ?? false }
        set { isTagsMigrationSheetShownValue = newValue }
    }

    public var docsSheetsEnabled: Bool {
        get { featureFlagCatalog.docsSheetsEnabled }
        set { featureFlagCatalog.docsSheetsEnabled = newValue }
    }

    public var docsSheetsDisabled: Bool {
        get { featureFlagCatalog.docsSheetsDisabled }
        set { featureFlagCatalog.docsSheetsDisabled = newValue }
    }

    public var docsCreateNewSheetOnMobileEnabled: Bool {
        get { featureFlagCatalog.docsCreateNewSheetOnMobileEnabled }
        set { featureFlagCatalog.docsCreateNewSheetOnMobileEnabled = newValue }
    }

    @objc public dynamic var driveSettingsLayout: LayoutPreference {
        get { LayoutPreference(forcedFromValue: layout) }
        set { layout = newValue.rawValue }
    }

    @objc public dynamic var driveSettingsSort: Int {
        get { sort ?? SortPreference.modifiedDescending.rawValue }
        set { sort = newValue }
    }

    @objc public dynamic var driveSettingsRevisionRetentionDays: Int {
        get { revisionRetentionDays ?? 180 }
        set { revisionRetentionDays = newValue }
    }
    @objc public dynamic var driveSettingsB2BPhotosEnabled: Bool {
        get { b2bPhotosEnabled ?? false }
        set { b2bPhotosEnabled = newValue }
    }

    @objc public dynamic var driveSettingsDocsCommentsNotificationsEnabled: Bool {
        get { docsCommentsNotificationsEnabled ?? false }
        set { docsCommentsNotificationsEnabled = newValue }
    }

    @objc public dynamic var driveSettingsDocsCommentsNotificationsIncludeDocumentName: Bool {
        get { docsCommentsNotificationsIncludeDocumentName ?? false }
        set { docsCommentsNotificationsIncludeDocumentName = newValue }
    }

    @objc public dynamic var driveSettingsPhotoTags: [Int] {
        get { photoTags ?? [] }
        set { photoTags = newValue }
    }

    public var driveiOSSDKNodeOperations: Bool {
        get { featureFlagCatalog.driveiOSSDKNodeOperations }
        set { featureFlagCatalog.driveiOSSDKNodeOperations = newValue }
    }

    public var driveCryptoEncryptBlocksWithPgpAead: Bool {
        get { featureFlagCatalog.driveCryptoEncryptBlocksWithPgpAead }
        set { featureFlagCatalog.driveCryptoEncryptBlocksWithPgpAead = newValue }
    }

    public var driveMacFileProviderBatchingDisabled: Bool {
        get { featureFlagCatalog.driveMacFileProviderBatchingDisabled }
        set { featureFlagCatalog.driveMacFileProviderBatchingDisabled = newValue }
    }

    public var driveMacDecryptPassphraseIterativeDisabled: Bool {
        get { featureFlagCatalog.driveMacDecryptPassphraseIterativeDisabled }
        set { featureFlagCatalog.driveMacDecryptPassphraseIterativeDisabled = newValue }
    }

    public var driveDownloadVerificationDisabled: Bool {
        get { featureFlagCatalog.driveDownloadVerificationDisabled }
        set { featureFlagCatalog.driveDownloadVerificationDisabled = newValue }
    }

    public var driveUploadVerificationDisabled: Bool {
        get { featureFlagCatalog.driveUploadVerificationDisabled }
        set { featureFlagCatalog.driveUploadVerificationDisabled = newValue }
    }

    public var previousAppVersion: Version? {
        get {
            if let version = previousAppVersionValue {
                return Version(version)
            } else {
                return nil
            }
        }
        set { previousAppVersionValue = newValue?.description }
    }

    @objc public dynamic var upgradeRequirementResult: UpgradeRequirementResult? {
        get {
            guard let data = upgradeRequirementResultValue else { return nil }
            do {
                return try JSONDecoder.default.decode(UpgradeRequirementResult.self, from: data)
            } catch {
                Log.error("Decode upgradeRequirementResultValue failed", error: error, domain: .storage)
                upgradeRequirementResultValue = nil
                return nil
            }
        }
        set {
            do {
                if let newValue {
                    let data = try JSONEncoder.default.encode(newValue)
                    upgradeRequirementResultValue = data
                } else {
                    upgradeRequirementResultValue = nil
                }
            } catch {
                Log.error("Encode upgradeRequirementResult failed", error: error, domain: .storage)
            }
        }
    }

    @objc public dynamic var hasDismissedUpgradeBanner: Bool {
        get { hasDismissedUpgradeBannerValue ?? false }
        set { hasDismissedUpgradeBannerValue = newValue }
    }

    public var iOSRefactoredFinder: Bool {
        get { iOSRefactoredFinderValue ?? false }
        set { iOSRefactoredFinderValue = newValue }
    }
}

#if DEBUG
extension LocalSettings {
    public func clearDefaultHomeTab() {
        defaultHomeTabTagValue = nil
    }

    public func clearPromotedNewFeatures() {
        promotedNewFeaturesValue = nil
    }
}
#endif

public extension LocalSettings {
    // Please do not create new instances of this class. Use the shared instance instead.
    static let shared = LocalSettings(suite: .group(named: Constants.appGroup))
}
