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

protocol PhotosBackupCompleteController {
    var isComplete: AnyPublisher<Bool, Never> { get }
}

final class LocalPhotosBackupCompleteController: PhotosBackupCompleteController {
    private let progressController: PhotosBackupProgressController
    private let timerFactory: TimerFactory
    private var previousProgress: PhotosBackupProgress?
    private let subject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?

    var isComplete: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    init(progressController: PhotosBackupProgressController, timerFactory: TimerFactory) {
        self.progressController = progressController
        self.timerFactory = timerFactory
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        progressController.progress
            .sink { [weak self] progress in
                self?.handleUpdate(progress)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ progress: PhotosBackupProgress?) {
        if progress == nil && previousProgress != nil {
            markComplete()
        } else {
            subject.send(false)
            timer?.cancel()
        }
        previousProgress = progress
    }

    private func markComplete() {
        subject.send(true)
        timer = timerFactory.makeTimer(interval: 3)
            .sink { [weak self] in
                self?.subject.send(false)
            }
    }
}
