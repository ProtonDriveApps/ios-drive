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
    var hasProtonDocumentCreation: Bool { get }
    var hasSharing: Bool { get }
    var hasSharingInvitations: Bool { get }
    var hasSharingExternalInvitations: Bool { get }
    var hasSharingEditing: Bool { get }
    var hasAcceptRejectInvitations: Bool { get }
    var hasPublicShareEditMode: Bool { get }
    var hasRatingIOSDrive: Bool { get }
    var hasRatingBooster: Bool { get }
    var hasBookmarks: Bool { get }
    var hasRefreshableBlockDownloadLink: Bool { get }
    /// Gates creation of new photo volume OR possibility to migrate legacy share
    var hasAlbums: Bool { get }
    var hasAlbumsActions: Bool { get }
    var hasComputers: Bool { get }
    var hasCopy: Bool { get }
    var hasAlbumsSharing: Bool { get }
    var hasPhotosTagsMigration: Bool { get }
    var hasProtonSheetCreation: Bool { get }
    var hasDebugMode: Bool { get }
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

    public var hasProtonDocumentCreation: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        // Only guarded by killswitch
        return !featureFlagsStore.isFeatureEnabled(.driveDocsDisabled)
    }

    public var hasSharing: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return !featureFlagsStore.isFeatureEnabled(.driveSharingDisabled)
    }

    public var hasSharingInvitations: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return hasSharing && featureFlagsStore.isFeatureEnabled(.driveSharingInvitations)
    }

    public var hasSharingExternalInvitations: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return hasSharingInvitations && featureFlagsStore.isFeatureEnabled(.driveSharingExternalInvitations) && !featureFlagsStore.isFeatureEnabled(.driveSharingExternalInvitationsDisabled)
    }

    public var hasSharingEditing: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return hasSharing && !featureFlagsStore.isFeatureEnabled(.driveSharingEditingDisabled)
    }
    
    public var hasPublicShareEditMode: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.drivePublicShareEditMode) && !featureFlagsStore.isFeatureEnabled(.drivePublicShareEditModeDisabled)
    }

    public var hasAcceptRejectInvitations: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }
        return hasSharing && featureFlagsStore.isFeatureEnabled(.driveMobileSharingInvitationsAcceptReject)
    }

    public var hasRatingBooster: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.driveRatingBooster)
    }
    
    public var hasRatingIOSDrive: Bool {
        // Enable it when you want to test rating popup
        guard !buildType.isDev else {
            // Dev will disable this feature always, no matter what
            return false
        }
        return featureFlagsStore.isFeatureEnabled(.ratingIOSDrive)
    }

    public var hasBookmarks: Bool {
        guard !buildType.isDev else {
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.driveShareURLBookmarking) && !featureFlagsStore.isFeatureEnabled(.driveShareURLBookmarksDisabled)
    }

    public var hasRefreshableBlockDownloadLink: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.driveiOSRefreshableBlockDownloadLink)
    }

    public var hasAlbums: Bool {
        #if DEBUG
        if let overridenValue = getOverridenAlbumsValue() {
            return overridenValue
        }
        #endif
        return !featureFlagsStore.isFeatureEnabled(.driveAlbumsDisabled)
    }

    #if DEBUG
    private func getOverridenAlbumsValue() -> Bool? {
        guard buildType.isDev else {
            return nil
        }

        if DebugConstants.commandLineContains(flags: [.uiTests, .overrideAlbumsFeatureFlagToFalse]) {
            return false
        } else if DebugConstants.commandLineContains(flags: [.uiTests, .overrideAlbumsFeatureFlagToTrue]) {
            return true
        } else if !DebugConstants.commandLineContains(flags: [.uiTests]) {
            return true
        } else {
            return nil
        }
    }
    #endif

    public var hasAlbumsActions: Bool {
        if buildType.isDev {
            return true
        }
        return !featureFlagsStore.isFeatureEnabled(.driveAlbumsDisabled)
    }

    public var hasAlbumsSharing: Bool {
        if buildType.isDev {
            return true
        }
        return hasSharing && !featureFlagsStore.isFeatureEnabled(.driveAlbumsDisabled)
    }

    public var hasComputers: Bool {
        guard !buildType.isDev else {
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.driveiOSComputers) && !featureFlagsStore.isFeatureEnabled(.driveiOSComputersDisabled)
    }

    public var hasCopy: Bool {
        if buildType.isDev {
            // Dev will have this feature always, no matter what
            return true
        }
        return !featureFlagsStore.isFeatureEnabled(.driveCopyDisabled)
    }

    public var hasPhotosTagsMigration: Bool {
        guard !buildType.isDev else {
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.drivePhotosTagsMigration) &&
               !featureFlagsStore.isFeatureEnabled(.drivePhotosTagsMigrationDisabled)
    }

    public var hasProtonSheetCreation: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return featureFlagsStore.isFeatureEnabled(.docsSheetsEnabled) &&
        featureFlagsStore.isFeatureEnabled(.docsCreateNewSheetOnMobileEnabled) &&
        !featureFlagsStore.isFeatureEnabled(.docsSheetsDisabled)
    }

    public var hasDebugMode: Bool {
        guard !buildType.isDev else {
            return true
        }

        return featureFlagsStore.isFeatureEnabled(.driveiOSDebugMode)
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
