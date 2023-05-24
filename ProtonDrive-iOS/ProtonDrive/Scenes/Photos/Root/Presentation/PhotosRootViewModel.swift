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

enum PhotosRootState {
    case onboarding
    case permissions
    case gallery
}

protocol PhotosRootViewModelProtocol: ObservableObject {
    var state: PhotosRootState { get }
    var title: String { get }
    func openMenu()
}

final class PhotosRootViewModel: PhotosRootViewModelProtocol {
    private let coordinator: PhotosRootCoordinator
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private var cancellables = Set<AnyCancellable>()

    @Published var state: PhotosRootState = .onboarding
    let title = "Photos"

    init(coordinator: PhotosRootCoordinator, settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController) {
        self.coordinator = coordinator
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(authorizationController.permissions, settingsController.isEnabled)
            .sink { [weak self] permissions, isBackupEnabled in
                self?.handle(permissions: permissions, isBackupEnabled: isBackupEnabled)
            }
            .store(in: &cancellables)
    }

    private func handle(permissions: PhotoLibraryPermissions, isBackupEnabled: Bool) {
        switch (permissions, isBackupEnabled) {
        case (_, false):
            state = .onboarding
        case (.restricted, _):
            state = .permissions
        case (.full, true):
            state = .gallery
        case (.undetermined, true):
            state = .onboarding
        }
    }

    func openMenu() {
        coordinator.openMenu()
    }
}
