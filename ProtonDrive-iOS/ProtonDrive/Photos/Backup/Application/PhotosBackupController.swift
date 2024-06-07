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

enum PhotosBackupAvailability: Equatable {
    case available
    case locked
    case unavailable
}

protocol PhotosBackupController {
    var isAvailable: AnyPublisher<PhotosBackupAvailability, Never> { get }
}

final class DrivePhotosBackupController: PhotosBackupController {
    private let authorizationController: PhotoLibraryAuthorizationController
    private let settingsController: PhotoBackupSettingsController
    private let bootstrapController: PhotosBootstrapController
    private let lockController: PhotoBackupConstraintController
    private var cancellables = Set<AnyCancellable>()
    private let isAvailableSubject = CurrentValueSubject<PhotosBackupAvailability, Never>(.unavailable)

    var isAvailable: AnyPublisher<PhotosBackupAvailability, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }

    init(authorizationController: PhotoLibraryAuthorizationController, settingsController: PhotoBackupSettingsController, bootstrapController: PhotosBootstrapController, lockController: PhotoBackupConstraintController) {
        self.authorizationController = authorizationController
        self.settingsController = settingsController
        self.bootstrapController = bootstrapController
        self.lockController = lockController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest4(authorizationController.permissions, settingsController.isEnabled, bootstrapController.isReady, lockController.constraint)
            .map { permissions, isSettingsEnabled, isBootstraped, isLocked -> PhotosBackupAvailability in
                if permissions == .full && isSettingsEnabled && isBootstraped {
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
}
