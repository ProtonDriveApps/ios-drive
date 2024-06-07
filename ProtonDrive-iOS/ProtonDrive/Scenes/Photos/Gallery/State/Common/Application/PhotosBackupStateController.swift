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

enum PhotosBackupState: Equatable {
    case empty
    case inProgress(PhotosBackupProgress)
    case complete
    case completeWithFailures(Int)
    case disabled
    case restrictedPermissions
    case networkConstrained
    case storageConstrained
    case quotaConstrained
    case featureFlag
    case applicationStateConstrained
    case libraryLoading
}

protocol PhotosBackupStateController {
    var state: AnyPublisher<PhotosBackupState, Never> { get }
}

final class LocalPhotosBackupStateController: PhotosBackupStateController {
    private let progressController: PhotosBackupProgressController
    private let failuresController: PhotosBackupFailuresController
    private let completeController: PhotosBackupCompleteController
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let networkController: PhotoBackupConstraintController
    private let quotaController: PhotoBackupConstraintController
    private let availableSpaceController: PhotoBackupConstraintController
    private let featureFlagController: PhotoBackupConstraintController
    private let applicationStateController: PhotoBackupConstraintController
    private let loadController: PhotoLibraryLoadController
    private let strategy: PhotosBackupStateStrategy
    private let throttleResource: ThrottleResource
    private let subject = CurrentValueSubject<PhotosBackupState, Never>(.empty)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<PhotosBackupState, Never> {
        subject.eraseToAnyPublisher()
    }

    init(progressController: PhotosBackupProgressController, failuresController: PhotosBackupFailuresController, completeController: PhotosBackupCompleteController, settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, networkController: PhotoBackupConstraintController, quotaController: PhotoBackupConstraintController, availableSpaceController: PhotoBackupConstraintController, featureFlagController: PhotoBackupConstraintController, applicationStateController: PhotoBackupConstraintController, loadController: PhotoLibraryLoadController, strategy: PhotosBackupStateStrategy, throttleResource: ThrottleResource) {
        self.progressController = progressController
        self.failuresController = failuresController
        self.completeController = completeController
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        self.networkController = networkController
        self.quotaController = quotaController
        self.availableSpaceController = availableSpaceController
        self.featureFlagController = featureFlagController
        self.applicationStateController = applicationStateController
        self.loadController = loadController
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
        let progressPublisher = Publishers.CombineLatest4(progressController.progress, completeController.isComplete, failuresController.count, loadController.isLoading).eraseToAnyPublisher()
        let throttledProgressPublisher = throttleResource.throttle(publisher: progressPublisher, milliseconds: 1000)
        let cloudPublisher = Publishers.CombineLatest(quotaController.constraint, featureFlagController.constraint)
        let availabilityPublisher = Publishers.CombineLatest4(settingsController.isEnabled, authorizationController.permissions, networkController.constraint, applicationStateController.constraint)

        return Publishers.CombineLatest4(throttledProgressPublisher, availabilityPublisher, cloudPublisher, availableSpaceController.constraint)
            .map { (progresses, availabilities, cloud, isStorageConstrained) in
                PhotosBackupStatesInput(
                    progress: progresses.0,
                    failures: progresses.2,
                    isComplete: progresses.1,
                    isLibraryLoading: progresses.3,
                    isBackupEnabled: availabilities.0,
                    permissions: availabilities.1,
                    isNetworkConstrained: availabilities.2,
                    isQuotaConstrained: cloud.0,
                    isStorageConstrained: isStorageConstrained,
                    isFeatureFlagConstrained: cloud.1,
                    isApplicationStateConstrained: availabilities.3
                )
            }
            .compactMap { [weak self] input in
                guard let self else { return nil }
                let state = self.strategy.map(input: input)
                Log.debug("Backup state: \(state)", domain: .photosProcessing)
                return state
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

extension LocalPhotosBackupStateController: WorkerState {
    var isWorking: Bool {
        subject.value == .libraryLoading
    }
}
