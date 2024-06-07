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

enum PhotosProcessingAvailability {
    case none
    case full
    case limited
}

protocol PhotosProcessingAvailableController {
    var availability: AnyPublisher<PhotosProcessingAvailability, Never> { get }
}

final class ConcretePhotosProcessingAvailableController: PhotosProcessingAvailableController {
    private let backupController: PhotosBackupController
    private let constraintsController: PhotoBackupConstraintsController
    private let computationalAvailabilityController: ComputationalAvailabilityController
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<PhotosProcessingAvailability, Never>(.none)

    var availability: AnyPublisher<PhotosProcessingAvailability, Never> {
        subject.eraseToAnyPublisher()
    }

    init(backupController: PhotosBackupController, constraintsController: PhotoBackupConstraintsController, computationalAvailabilityController: ComputationalAvailabilityController) {
        self.backupController = backupController
        self.constraintsController = constraintsController
        self.computationalAvailabilityController = computationalAvailabilityController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest3(backupController.isAvailable, constraintsController.constraints, computationalAvailabilityController.availability)
            .map { availability, constraints, computationalAvailability -> PhotosProcessingAvailability in
                guard availability == .available && constraints.isEmpty else {
                    return .none
                }

                switch computationalAvailability {
                case .foreground:
                    return .full
                case .processingTask:
                    return .limited
                case .suspended, .extensionTask:
                    // Intentionally not adding `extensionTask`. That one is short lived and processing should be stopped.
                    return .none
                }
            }
            .removeDuplicates()
            .sink { [weak self] availability in
                Log.debug("Photos processing state changed, availability: \(availability)", domain: .photosProcessing)
                self?.subject.send(availability)
            }
            .store(in: &cancellables)
    }
}
