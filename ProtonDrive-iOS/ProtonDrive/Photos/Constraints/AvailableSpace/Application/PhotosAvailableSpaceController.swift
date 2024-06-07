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
import Foundation
import PDCore

final class PhotosAvailableSpaceController: PhotoBackupConstraintController {
    private let backupController: PhotosBackupController
    private let computationalAvailabilityController: ComputationalAvailabilityController
    private let interactor: PhotosAvailableSpaceInteractor
    private let constraintSubject: CurrentValueSubject<Bool, Never>
    private var cancellables = Set<AnyCancellable>()

    var constraint: AnyPublisher<Bool, Never> {
        constraintSubject.eraseToAnyPublisher()
    }

    init(backupController: PhotosBackupController, computationalAvailabilityController: ComputationalAvailabilityController, interactor: PhotosAvailableSpaceInteractor) {
        self.backupController = backupController
        self.computationalAvailabilityController = computationalAvailabilityController
        self.interactor = interactor
        constraintSubject = .init(false)
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(backupController.isAvailable, computationalAvailabilityController.availability)
            .map { availability, computationalAvailability in
                // Intentionally not adding `extensionTask`. That one is short lived and processing should be stopped.
                let isComputationallyAvailable = [ComputationalAvailability.foreground, .processingTask].contains(computationalAvailability)
                return availability == .available && isComputationallyAvailable
            }
            .sink { [weak self] isAvailable in
                self?.handleBackup(isAvailable)
            }
            .store(in: &cancellables)

        interactor.constraint
            .sink { [weak self] isConstrained in
                Log.debug("PhotosAvailableSpaceController isConstrained: \(isConstrained)", domain: .photosProcessing)
                self?.constraintSubject.send(isConstrained)
            }
            .store(in: &cancellables)
    }

    private func handleBackup(_ isAvailable: Bool) {
        if isAvailable {
            interactor.execute()
        } else {
            interactor.cancel()
        }
    }
}
