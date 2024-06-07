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
    private let failuresController: PhotosBackupFailuresController
    private let retryTriggerController: PhotoLibraryLoadRetryTriggerController
    private let timerFactory: TimerFactory
    private let subject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?

    var isComplete: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    init(progressController: PhotosBackupProgressController, failuresController: PhotosBackupFailuresController, retryTriggerController: PhotoLibraryLoadRetryTriggerController, timerFactory: TimerFactory) {
        self.progressController = progressController
        self.failuresController = failuresController
        self.retryTriggerController = retryTriggerController
        self.timerFactory = timerFactory
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        progressController.progress
            .dropFirst()
            .combineLatest(failuresController.count)
            .sink { [weak self] progress, failures in
                self?.handleUpdate(progress, failures: failures)
            }
            .store(in: &cancellables)

        retryTriggerController.updatePublisher
            .sink { [weak self] in
                self?.resetState()
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ progress: PhotosBackupProgress?, failures: Int) {
        if progress?.isCompleted ?? false {
            if failures > 0 {
                markCompleteWithFailures()
            } else {
                markComplete()
            }
        } else {
            resetState()
        }
    }

    private func resetState() {
        subject.send(false)
        timer?.cancel()
    }
    
    private func markCompleteWithFailures() {
        subject.send(true)
    }

    private func markComplete() {
        subject.send(true)
        timer = timerFactory.makeTimer(interval: 3)
            .sink { [weak self] in
                self?.resetState()
            }
    }
}
