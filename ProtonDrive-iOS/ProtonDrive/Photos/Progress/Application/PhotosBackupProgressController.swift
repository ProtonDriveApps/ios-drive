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

struct PhotosBackupProgress: Equatable {
    let total: Int
    let inProgress: Int

    func isCompleted() -> Bool {
        return inProgress == 0
    }
}

protocol PhotosBackupProgressController {
    var progress: AnyPublisher<PhotosBackupProgress?, Never> { get }
}

final class LocalPhotosBackupProgressController: PhotosBackupProgressController {
    private let libraryLoadController: PhotoLibraryLoadProgressController
    private let uploadsController: PhotosUploadsProgressController
    private let subject = CurrentValueSubject<PhotosBackupProgress?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    var progress: AnyPublisher<PhotosBackupProgress?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(libraryLoadController: PhotoLibraryLoadProgressController, uploadsController: PhotosUploadsProgressController) {
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
                progress.isCompleted() ? nil : progress
            }
            .removeDuplicates()
            .sink { [weak self] progress in
                self?.subject.send(progress)
            }
            .store(in: &cancellables)
    }
}
