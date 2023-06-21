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

enum PhotosUploadState: Equatable {
    case empty
    case inProgress(PhotosBackupProgress)
    case complete
    case disabled
    case restrictedPermissions
    case networkConstrained
    case outOfStorage
}

protocol PhotosUploadStateController {
    var state: AnyPublisher<PhotosUploadState, Never> { get }
}

final class LocalPhotosUploadStateController: PhotosUploadStateController {
    private let progressController: PhotosBackupProgressController
    private let subject = CurrentValueSubject<PhotosUploadState, Never>(.empty)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<PhotosUploadState, Never> {
        subject.eraseToAnyPublisher()
    }

    init(progressController: PhotosBackupProgressController) {
        self.progressController = progressController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        progressController.progress
            .sink { [weak self] progress in
                self?.handleProgress(progress)
            }
            .store(in: &cancellables)
    }

    private func handleProgress(_ progress: PhotosBackupProgress?) {
        if let progress {
            subject.send(.inProgress(progress))
        } else {
            subject.send(.empty)
        }
    }
}
