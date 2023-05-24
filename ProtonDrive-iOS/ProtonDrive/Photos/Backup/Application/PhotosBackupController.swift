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

protocol PhotosBackupController {
    var isAvailable: AnyPublisher<Bool, Never> { get }
}

final class DrivePhotosBackupController: PhotosBackupController {
    private let authorizationController: PhotoLibraryAuthorizationController
    private let settingsController: PhotoBackupSettingsController
    private var cancellables = Set<AnyCancellable>()
    private let isAvailableSubject = CurrentValueSubject<Bool, Never>(false)

    var isAvailable: AnyPublisher<Bool, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }

    init(authorizationController: PhotoLibraryAuthorizationController, settingsController: PhotoBackupSettingsController) {
        self.authorizationController = authorizationController
        self.settingsController = settingsController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(authorizationController.permissions, settingsController.isEnabled)
            .map { $0 == .full && $1 }
            .sink { [weak self] isAvailable in
                self?.isAvailableSubject.send(isAvailable)
            }
            .store(in: &cancellables)
    }
}
