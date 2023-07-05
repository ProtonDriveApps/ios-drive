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

final class LocalPhotosBackupUploadAvailableController: PhotosBackupUploadAvailableController {
    private let backupController: PhotosBackupController
    private let networkConstraintController: PhotoBackupConstraintController
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<Bool, Never>(false)

    var isAvailable: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    init(backupController: PhotosBackupController, networkConstraintController: PhotoBackupConstraintController) {
        self.backupController = backupController
        self.networkConstraintController = networkConstraintController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(backupController.isAvailable, networkConstraintController.constraint)
            .map { isAvailable, isConstrained in
                isAvailable && !isConstrained
            }
            .sink { [weak self] isAvailable in
                self?.subject.send(isAvailable)
            }
            .store(in: &cancellables)
    }
}
