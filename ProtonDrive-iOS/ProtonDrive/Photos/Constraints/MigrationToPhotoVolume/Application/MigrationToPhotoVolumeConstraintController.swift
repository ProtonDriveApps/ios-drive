// Copyright (c) 2025 Proton AG
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
import PDPhotos
import ProtonCoreNetworking

final class MigrationToPhotoVolumeConstraintController: PhotoBackupConstraintController {
    private let errorControllers: [ErrorController]
    private var subject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    var constraint: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    init(errorControllers: [ErrorController]) {
        self.errorControllers = errorControllers
        Publishers.MergeMany(errorControllers.map(\.errorPublisher))
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error) {
        guard let responseError = error as? ResponseError else {
            return
        }

        // This is unrecoverable constraint. The only way to bypass this is to install new version which will get
        // albums feature where we'll be able to handle migration properly and recover.
        // No upload or listing will be permitted if this happens.
        if responseError.isPhotoVolumeMigrationError {
            subject.send(true)
        }
    }
}
