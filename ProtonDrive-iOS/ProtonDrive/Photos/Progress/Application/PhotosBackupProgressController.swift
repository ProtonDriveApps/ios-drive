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

protocol PhotosBackupProgressController {
    var progress: AnyPublisher<PhotosBackupProgress?, Never> { get }
}

final class LocalPhotosBackupProgressController: PhotosBackupProgressController {
    private let libraryLoadController: PhotosLoadProgressController
    private let uploadsController: PhotosLoadProgressController
    private let subject = CurrentValueSubject<PhotosBackupProgress?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    var progress: AnyPublisher<PhotosBackupProgress?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(libraryLoadController: PhotosLoadProgressController, uploadsController: PhotosLoadProgressController) {
        self.libraryLoadController = libraryLoadController
        self.uploadsController = uploadsController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(libraryLoadController.progress, uploadsController.progress)
            .map { loadProgress, uploadProgress in
                PhotosBackupProgress(
                    total: loadProgress.total + uploadProgress.total,
                    inProgress: loadProgress.inProgress + uploadProgress.inProgress
                )
            }
            .map { progress in
                progress.isCompleted ? nil : progress
            }
            .removeDuplicates()
            .sink { [weak self] progress in
                self?.handleUpdate(progress)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ progress: PhotosBackupProgress?) {
        if progress == nil {
            libraryLoadController.resetTotal()
            uploadsController.resetTotal()
        }
        subject.send(progress)
    }
}
