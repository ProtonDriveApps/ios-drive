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

protocol PhotosBackupProgressController: WorkingNotifier {
    var progress: AnyPublisher<PhotosBackupProgress?, Never> { get }
}

final class LocalPhotosBackupProgressController: PhotosBackupProgressController {
    private let libraryLoadController: PhotosLoadProgressController
    private let uploadsController: PhotosLoadProgressController
    private let loadController: PhotoLibraryLoadController
    private let debounceResource: DebounceResource
    private let subject = CurrentValueSubject<PhotosBackupProgress?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    struct ProgressNotification: Equatable {
        let progress: PhotosBackupProgress
        let isInitialLoad: Bool
    }

    var progress: AnyPublisher<PhotosBackupProgress?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(libraryLoadController: PhotosLoadProgressController, uploadsController: PhotosLoadProgressController, loadController: PhotoLibraryLoadController, debounceResource: DebounceResource) {
        self.libraryLoadController = libraryLoadController
        self.uploadsController = uploadsController
        self.loadController = loadController
        self.debounceResource = debounceResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest3(libraryLoadController.progress, uploadsController.progress, loadController.isLoading)
            .map { loadProgress, uploadProgress, isInitialLoad in
                let progress = PhotosBackupProgress(
                    total: loadProgress.total + uploadProgress.total,
                    inProgress: loadProgress.inProgress + uploadProgress.inProgress
                )
                return ProgressNotification(progress: progress, isInitialLoad: isInitialLoad)
            }
            .removeDuplicates()
            .sink { [weak self] progress in
                self?.handleUpdate(progress)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ notification: ProgressNotification) {
        if notification.progress.isCompleted {
            libraryLoadController.resetTotal()
            uploadsController.resetTotal()
        }

        // In case of initial load we don't want to debounce to make the first progress appear asap and correct.
        // After initial load the progresses will be received async and to avoid jumps we debounce them.
        if notification.isInitialLoad {
            subject.send(notification.progress)
        } else {
            debounceResource.debounce(interval: 0.1) { [weak self] in
                self?.subject.send(notification.progress)
            }
        }
    }
}

extension PhotosBackupProgressController {
    var isWorkingPublisher: AnyPublisher<Bool, Never> {
        progress
            .map { progress in
                guard let progress else { return false }
                return !progress.isCompleted
            }
            .eraseToAnyPublisher()
    }
}
