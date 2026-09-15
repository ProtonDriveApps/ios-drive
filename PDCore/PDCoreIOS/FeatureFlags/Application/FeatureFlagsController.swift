// Copyright (c) 2024 Proton AG
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

import Combine
import PDCore

public protocol FeatureFlagsControllerProtocol {
    // Publisher that triggers update every time FFs are updated
    var updatePublisher: AnyPublisher<Void, Never> { get }
    // Actual feature flags combinations, taking into account build type, killswitches and rollout flags
    var hasSharing: Bool { get }
    var hasSharingExternalInvitations: Bool { get }
    var hasSharingAdminPermissions: Bool { get }
    var hasPublicShareEditMode: Bool { get }
    var hasRatingIOSDrive: Bool { get }
    var hasRatingBooster: Bool { get }
    var hasBookmarks: Bool { get }
    /// Gates creation of new photo volume OR possibility to migrate legacy share
    var hasCopy: Bool { get }
    var hasPhotosTagsMigration: Bool { get }
    var hasProtonSheetCreation: Bool { get }
    var hasDebugMode: Bool { get }
    var hasPaymentsV2: Bool { get }
    var hasCustomUpsellModal: Bool { get }
    var needsSDKNodeOperationPerformer: Bool { get }
    var hasSDKCreateFolder: Bool { get }
    var hasSDKTrashNode: Bool { get }
    var hasSDKDeviceOperations: Bool { get }
    var hasGradualRolloutChannel: Bool { get }
    var hasRefactoredFinderView: Bool { get }
    var hasRefactoredFinderViewByDefault: Bool { get }
    /// Makes current value publisher for the specific FF
    var hasUnlimitedPickerSelection: Bool { get }
    var hasUnlimitedDownloads: Bool { get }
    var hasPhotosGridZoom: Bool { get }
    func makePublisher(keyPath: KeyPath<FeatureFlagsControllerProtocol, Bool>) -> AnyPublisher<Bool, Never>
}

public final class FeatureFlagsController: FeatureFlagsControllerProtocol {
    private let buildType: BuildType
    private let featureFlagProvider: DriveFeatureFlagsProvider
    private let experimentalFeatureFlagProvider: ExperimentalFeatureFlagProvider
    private let subject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init(
        buildType: BuildType,
        featureFlagProvider: DriveFeatureFlagsProvider,
        experimentalFeatureFlagProvider: ExperimentalFeatureFlagProvider
    ) {
        self.buildType = buildType
        self.featureFlagProvider = featureFlagProvider
        self.experimentalFeatureFlagProvider = experimentalFeatureFlagProvider
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        featureFlagProvider.updatePublisher
            .sink { [weak self] in
                self?.subject.send()
            }
            .store(in: &cancellables)
    }

    public var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    public var hasSharing: Bool {
        !featureFlagProvider.isEnabled(flag: .driveSharingDisabled)
    }

    public var hasSharingExternalInvitations: Bool {
        return hasSharing && featureFlagProvider.isEnabled(flag: .driveSharingExternalInvitations) && !featureFlagProvider.isEnabled(flag: .driveSharingExternalInvitationsDisabled)
    }

    public var hasSharingAdminPermissions: Bool {
        return hasSharing && featureFlagProvider.isEnabled(flag: .driveSharingAdminPermissions)
    }
    
    public var hasPublicShareEditMode: Bool {
        return featureFlagProvider.isEnabled(flag: .drivePublicShareEditMode) && !featureFlagProvider.isEnabled(flag: .drivePublicShareEditModeDisabled)
    }

    public var hasRatingBooster: Bool {
        return featureFlagProvider.isEnabled(flag: .driveRatingBooster)
    }
    
    public var hasRatingIOSDrive: Bool {
        return featureFlagProvider.isEnabled(flag: .ratingIOSDrive)
    }

    public var hasBookmarks: Bool {
        return featureFlagProvider.isEnabled(flag: .driveShareURLBookmarking) && !featureFlagProvider.isEnabled(flag: .driveShareURLBookmarksDisabled)
    }

    public var hasCopy: Bool {
        return !featureFlagProvider.isEnabled(flag: .driveCopyDisabled)
    }

    public var hasPhotosTagsMigration: Bool {
        return !featureFlagProvider.isEnabled(flag: .drivePhotosTagsMigrationDisabled)
    }

    public var hasProtonSheetCreation: Bool {
        return featureFlagProvider.isEnabled(flag: .docsSheetsEnabled)
            && featureFlagProvider.isEnabled(flag: .docsCreateNewSheetOnMobileEnabled)
            && !featureFlagProvider.isEnabled(flag: .docsSheetsDisabled)
    }

    public var hasDebugMode: Bool {
        return featureFlagProvider.isEnabled(flag: .driveiOSDebugMode)
    }

    public var hasPaymentsV2: Bool {
        return featureFlagProvider.isEnabled(flag: .driveiOSPaymentsV2)
    }

    public var hasCustomUpsellModal: Bool {
        return featureFlagProvider.isEnabled(flag: .driveMobileUpsellPlan)
    }

    public var hasSDKCryptoEncryptBlocksWithPgpAead: Bool {
        return featureFlagProvider.isEnabled(flag: .driveCryptoEncryptBlocksWithPgpAead)
    }
    
    public var hasDriveDownloadVerificationDisabled: Bool {
        return featureFlagProvider.isEnabled(flag: .driveDownloadVerificationDisabled)
    }

    /// /// Any of the SDK node-operation sub-features that require the performer to exist
    public var needsSDKNodeOperationPerformer: Bool {
        return featureFlagProvider.isEnabled(flag: .driveiOSSDKNodeOperations) ||
               hasSDKCreateFolder ||
               hasSDKTrashNode ||
               hasSDKDeviceOperations
    }

    public var hasSDKCreateFolder: Bool {
        return featureFlagProvider.isEnabled(flag: .driveiOSSDKCreateFolder)
    }

    public var hasSDKTrashNode: Bool {
        return featureFlagProvider.isEnabled(flag: .driveiOSSDKTrashNode)
    }

    public var hasSDKDeviceOperations: Bool {
        return featureFlagProvider.isEnabled(flag: .driveiOSSDKDevicesOperations)
    }

    public var hasGradualRolloutChannel: Bool {
        featureFlagProvider.isEnabled(flag: .driveMacGradualRolloutChannelEnabled)
    }

    public var hasRefactoredFinderView: Bool {
        experimentalFeatureFlagProvider.iOSRefactoredFinder || hasRefactoredFinderViewByDefault
    }

    public var hasRefactoredFinderViewByDefault: Bool {
        buildType.isQaOrBelow
    }

    private var isTestingEnabled: Bool {
        featureFlagProvider.isEnabled(flag: .driveClientTestsEnabled)
    }

    public var hasUnlimitedPickerSelection: Bool {
        buildType == .dev ||
            featureFlagProvider.isEnabled(flag: .driveiOSUnlimitedPickerSelection) ||
            isTestingEnabled
    }

    public var hasUnlimitedDownloads: Bool {
        buildType == .dev ||
            featureFlagProvider.isEnabled(flag: .driveiOSDownloadMultiple) ||
            isTestingEnabled
    }

    public var hasPhotosGridZoom: Bool {
        featureFlagProvider.isEnabled(flag: .driveiOSPhotosGridZoom)
    }

    public func makePublisher(keyPath: KeyPath<FeatureFlagsControllerProtocol, Bool>) -> AnyPublisher<Bool, Never> {
        let currentValue = self[keyPath: keyPath]
        let updatePublisher = updatePublisher
            .map { [weak self] in
                self?[keyPath: keyPath] ?? false
            }
        return CurrentValueSubject(currentValue).merge(with: updatePublisher)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
