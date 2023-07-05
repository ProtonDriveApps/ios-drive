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

enum PhotosBackupState: Equatable {
    case empty
    case inProgress(PhotosBackupProgress)
    case complete
    case disabled
    case restrictedPermissions
    case networkConstrained
}

protocol PhotosBackupStateController {
    var state: AnyPublisher<PhotosBackupState, Never> { get }
}

final class LocalPhotosBackupStateController: PhotosBackupStateController {
    private let progressController: PhotosBackupProgressController
    private let completeController: PhotosBackupCompleteController
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let networkController: PhotoBackupConstraintController
    private let strategy: PhotosBackupStateStrategy
    private let throttleResource: ThrottleResource
    private let subject = CurrentValueSubject<PhotosBackupState, Never>(.empty)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<PhotosBackupState, Never> {
        subject.eraseToAnyPublisher()
    }

    init(progressController: PhotosBackupProgressController, completeController: PhotosBackupCompleteController, settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, networkController: PhotoBackupConstraintController, strategy: PhotosBackupStateStrategy, throttleResource: ThrottleResource) {
        self.progressController = progressController
        self.completeController = completeController
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        self.networkController = networkController
        self.strategy = strategy
        self.throttleResource = throttleResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        let statePublisher = makePublisher()

        throttleResource.throttle(publisher: statePublisher, milliseconds: 100)
            .sink { [weak self] state in
                self?.subject.send(state)
            }
            .store(in: &cancellables)
    }

    private func makePublisher() -> AnyPublisher<PhotosBackupState, Never> {
        let progressPublisher = Publishers.CombineLatest(progressController.progress, completeController.isComplete)
        let availabilityPublisher = Publishers.CombineLatest3(settingsController.isEnabled, authorizationController.permissions, networkController.constraint)

        return Publishers.CombineLatest(progressPublisher, availabilityPublisher)
            .map { (progresses, availabilities) in
                PhotosBackupStatesInput(
                    progress: progresses.0,
                    isComplete: progresses.1,
                    isBackupEnabled: availabilities.0,
                    permissions: availabilities.1,
                    isNetworkConstrained: availabilities.2
                )
            }
            .compactMap { [weak self] input in
                self?.strategy.map(input: input)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
