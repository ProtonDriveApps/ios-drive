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
    var hasSDKUploadMain: Bool { get }
    var hasSDKUploadPhoto: Bool { get }
    var hasSDKDownloadMain: Bool { get }
    var hasSDKDownloadPhoto: Bool { get }
    var hasSDKNodeOperations: Bool { get }
    var hasGradualRolloutChannel: Bool { get }
    /// Makes current value publisher for the specific FF
    func makePublisher(keyPath: KeyPath<FeatureFlagsControllerProtocol, Bool>) -> AnyPublisher<Bool, Never>
}

public final class FeatureFlagsController: FeatureFlagsControllerProtocol {
    private let buildType: BuildType
    private let featureFlagsStore: ExternalFeatureFlagsStore
    private let updateRepository: FeatureFlagsUpdateRepository
    private let subject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init(buildType: BuildType, featureFlagsStore: ExternalFeatureFlagsStore, updateRepository: FeatureFlagsUpdateRepository) {
        self.buildType = buildType
        self.featureFlagsStore = featureFlagsStore
        self.updateRepository = updateRepository
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        updateRepository.updatePublisher
            .sink { [weak self] in
                self?.subject.send()
            }
            .store(in: &cancellables)
    }

    public var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    public var hasSharing: Bool {
        return !featureFlagsStore.isFeatureEnabled(.driveSharingDisabled)
    }

    public var hasSharingExternalInvitations: Bool {
        return hasSharing && featureFlagsStore.isFeatureEnabled(.driveSharingExternalInvitations) && !featureFlagsStore.isFeatureEnabled(.driveSharingExternalInvitationsDisabled)
    }
    
    public var hasPublicShareEditMode: Bool {
        return featureFlagsStore.isFeatureEnabled(.drivePublicShareEditMode) && !featureFlagsStore.isFeatureEnabled(.drivePublicShareEditModeDisabled)
    }

    public var hasRatingBooster: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveRatingBooster)
    }
    
    public var hasRatingIOSDrive: Bool {
        return featureFlagsStore.isFeatureEnabled(.ratingIOSDrive)
    }

    public var hasBookmarks: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveShareURLBookmarking) && !featureFlagsStore.isFeatureEnabled(.driveShareURLBookmarksDisabled)
    }

    public var hasCopy: Bool {
        return !featureFlagsStore.isFeatureEnabled(.driveCopyDisabled)
    }

    public var hasPhotosTagsMigration: Bool {
        return !featureFlagsStore.isFeatureEnabled(.drivePhotosTagsMigrationDisabled)
    }

    public var hasProtonSheetCreation: Bool {
        return featureFlagsStore.isFeatureEnabled(.docsSheetsEnabled) &&
        featureFlagsStore.isFeatureEnabled(.docsCreateNewSheetOnMobileEnabled) &&
        !featureFlagsStore.isFeatureEnabled(.docsSheetsDisabled)
    }

    public var hasDebugMode: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSDebugMode)
    }

    public var hasPaymentsV2: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSPaymentsV2)
    }

    public var hasSDKUploadMain: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSSDKUploadMain)
    }

    public var hasSDKUploadPhoto: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSSDKUploadPhoto)
    }

    public var hasSDKDownloadMain: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSSDKDownloadMain)
    }

    public var hasSDKDownloadPhoto: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSSDKDownloadPhoto)
    }

    public var hasSDKCryptoEncryptBlocksWithPgpAead: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveCryptoEncryptBlocksWithPgpAead)
    }
    
    public var hasDriveDownloadVerificationDisabled: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveDownloadVerificationDisabled)
    }

    public var hasSDKNodeOperations: Bool {
        return featureFlagsStore.isFeatureEnabled(.driveiOSSDKNodeOperations)
    }

    public var hasGradualRolloutChannel: Bool {
        featureFlagsStore.isFeatureEnabled(.driveMacGradualRolloutChannelEnabled)
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
