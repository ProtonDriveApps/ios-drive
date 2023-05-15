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

protocol PhotoLibraryLoadController {}

final class LocalPhotoLibraryLoadController: PhotoLibraryLoadController {
    private let authorizationController: PhotoLibraryAuthorizationController
    private let interactor: PhotoLibraryLoadInteractor
    private let settingsController: PhotoBackupSettingsController
    private var cancellables = Set<AnyCancellable>()

    init(authorizationController: PhotoLibraryAuthorizationController, settingsController: PhotoBackupSettingsController, interactor: PhotoLibraryLoadInteractor) {
        self.authorizationController = authorizationController
        self.settingsController = settingsController
        self.interactor = interactor
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(authorizationController.isAuthorized, settingsController.isEnabled)
            .map { $0 && $1 }
            .sink { [weak self] isBackupAvailable in
                self?.handleUpdate(isBackupAvailable: isBackupAvailable)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(isBackupAvailable: Bool) {
        if isBackupAvailable {
            interactor.execute()
        } else {
            interactor.cancel()
        }
    }
}
