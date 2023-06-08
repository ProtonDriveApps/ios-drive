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

protocol PhotoBackupConstraintsController {
    var constraints: AnyPublisher<PhotoBackupConstraints, Never> { get }
}

final class LocalPhotoBackupConstraintsController: PhotoBackupConstraintsController {
    private let storageController: PhotoBackupConstraintController
    private let networkController: PhotoBackupConstraintController
    private let constraintsSubject: CurrentValueSubject<PhotoBackupConstraints, Never> = .init([])
    private var cancellables = Set<AnyCancellable>()

    var constraints: AnyPublisher<PhotoBackupConstraints, Never> {
        constraintsSubject.eraseToAnyPublisher()
    }

    init(storageController: PhotoBackupConstraintController, networkController: PhotoBackupConstraintController) {
        self.storageController = storageController
        self.networkController = networkController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(storageController.constraint, networkController.constraint)
            .sink { [weak self] isStorageConstrained, isNetworkConstrained in
                self?.handleUpdate(isStorageConstrained: isStorageConstrained, isNetworkConstrained: isNetworkConstrained)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(isStorageConstrained: Bool, isNetworkConstrained: Bool) {
        let constraints = [
            isStorageConstrained ? PhotoBackupConstraint.storage : nil,
            isNetworkConstrained ? .network : nil,
        ].compactMap { $0 }
        constraintsSubject.send(Set(constraints))
    }
}
