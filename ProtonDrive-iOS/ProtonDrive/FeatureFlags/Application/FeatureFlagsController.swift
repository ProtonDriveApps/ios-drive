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

protocol FeatureFlagsControllerProtocol {
    // Publisher that triggers update every time FFs are updated
    var updatePublisher: AnyPublisher<Void, Never> { get }
    // Actual feature flags combinations, taking into account build type, killswitches and rollout flags
    var hasProtonDocumentInWebView: Bool { get }
    var hasProtonDocumentCreation: Bool { get }
    var hasSharing: Bool { get }
    var hasSharingInvitations: Bool { get }
    var hasSharingExternalInvitations: Bool { get }
    var hasSharingEditing: Bool { get }
    var hasPublicShareEditMode: Bool { get }
}

final class FeatureFlagsController: FeatureFlagsControllerProtocol {
    private let buildType: BuildType
    private let featureFlagsStore: ExternalFeatureFlagsStore
    private let updateRepository: FeatureFlagsUpdateRepository
    private let subject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(buildType: BuildType, featureFlagsStore: ExternalFeatureFlagsStore, updateRepository: FeatureFlagsUpdateRepository) {
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

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var hasProtonDocumentInWebView: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        // Any build with turned on FF
        return featureFlagsStore.isFeatureEnabled(.driveDocsWebView)
    }

    var hasProtonDocumentCreation: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        // Only guarded by killswitch
        return !featureFlagsStore.isFeatureEnabled(.driveDocsDisabled)
    }

    var hasSharing: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return featureFlagsStore.isFeatureEnabled(.driveiOSSharing) && !featureFlagsStore.isFeatureEnabled(.driveSharingDisabled)
    }

    var hasSharingInvitations: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return hasSharing && featureFlagsStore.isFeatureEnabled(.driveSharingInvitations)
    }

    var hasSharingExternalInvitations: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return hasSharingInvitations && featureFlagsStore.isFeatureEnabled(.driveSharingExternalInvitations) && !featureFlagsStore.isFeatureEnabled(.driveSharingExternalInvitationsDisabled)
    }

    var hasSharingEditing: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }

        return hasSharing && !featureFlagsStore.isFeatureEnabled(.driveSharingEditingDisabled)
    }
    
    var hasPublicShareEditMode: Bool {
        guard !buildType.isDev else {
            // Dev will have this feature always, no matter what
            return true
        }
        return featureFlagsStore.isFeatureEnabled(.drivePublicShareEditMode) && !featureFlagsStore.isFeatureEnabled(.drivePublicShareEditModeDisabled)
    }
}
