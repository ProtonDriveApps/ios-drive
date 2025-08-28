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

import Combine
import PDCore
import PDCoreIOS
import PDPhotos

final class DrivePhotosBackupController: PhotosBackupController {
    private let authorizationController: PhotoLibraryAuthorizationController
    private let settingsController: PhotoBackupSettingsController
    private let bootstrapController: PhotosBootstrapController
    private let lockController: PhotoBackupConstraintController
    private let b2BUserController: PhotoBackupConstraintController
    private let populatedStateController: PopulatedStateControllerProtocol
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private var cancellables = Set<AnyCancellable>()
    private let isAvailableSubject = CurrentValueSubject<PhotosBackupAvailability, Never>(.unavailable)

    var isAvailable: AnyPublisher<PhotosBackupAvailability, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }

    init(authorizationController: PhotoLibraryAuthorizationController, settingsController: PhotoBackupSettingsController, bootstrapController: PhotosBootstrapController, lockController: PhotoBackupConstraintController, b2BUserController: PhotoBackupConstraintController, populatedStateController: PopulatedStateControllerProtocol, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.authorizationController = authorizationController
        self.settingsController = settingsController
        self.bootstrapController = bootstrapController
        self.lockController = lockController
        self.b2BUserController = b2BUserController
        self.populatedStateController = populatedStateController
        self.featureFlagsController = featureFlagsController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        let constraintsPublisher = Publishers.CombineLatest3(lockController.constraint, populatedStateController.state, b2BUserController.constraint)
        let localStatePublisher = makeLocalStateIsReadyPublisher()
        Publishers.CombineLatest4(authorizationController.permissions, settingsController.isEnabled, constraintsPublisher, localStatePublisher)
            .map { permissions, isSettingsEnabled, constraints, localStateIsReady -> PhotosBackupAvailability in
                let isLocked = constraints.0
                let isPopulated = constraints.1 == .populated
                let isB2BConstrained = constraints.2
                if permissions == .full && isSettingsEnabled && localStateIsReady && isPopulated && !isB2BConstrained {
                    return isLocked ? PhotosBackupAvailability.locked : PhotosBackupAvailability.available
                } else {
                    return PhotosBackupAvailability.unavailable
                }
            }
            .removeDuplicates()
            .sink { [weak self] availability in
                Log.info("Photos backup availability: \(availability)", domain: .photosProcessing)
                self?.isAvailableSubject.send(availability)
            }
            .store(in: &cancellables)
    }

    private func makeLocalStateIsReadyPublisher() -> AnyPublisher<Bool, Never> {
        Publishers.CombineLatest(bootstrapController.state, featureFlagsController.makePublisher(keyPath: \.hasAlbums))
            .map { state, isAlbumsEnabled in
                switch state {
                case .notFound:
                    return false
                case .legacyShare:
                    // When albums FF is enabled, we don't allow backup to the legacy share
                    return !isAlbumsEnabled
                case .photoVolume:
                    return true
                }
            }
            .eraseToAnyPublisher()
    }
}
