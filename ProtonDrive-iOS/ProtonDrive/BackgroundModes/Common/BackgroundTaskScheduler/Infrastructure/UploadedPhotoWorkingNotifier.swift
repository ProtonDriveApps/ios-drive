// Copyright (c) 2024 Proton AG
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

import PDCore
import Combine

final class UploadedPhotoWorkingNotifier: WorkingNotifier {

    private let workerState: WorkerState
    private var backupController: ComputationalAvailabilityController
    private let uploadedPhotoPublisher: AnyPublisher<Void, Never>
    private var isWorkingSubject = PassthroughSubject<Bool, Never>()
    private var cancellables = Set<AnyCancellable>()

    private var isPerformingBackgroundWork = false

    init(
        workerState: WorkerState,
        backupController: ComputationalAvailabilityController,
        uploadedPhotoPublisher: AnyPublisher<Void, Never>
    ) {
        self.workerState = workerState
        self.backupController = backupController
        self.uploadedPhotoPublisher = uploadedPhotoPublisher

        backupController.availability
            .sink { [weak self] availability in
                guard let self else { return }
                self.isPerformingBackgroundWork = availability == .processingTask
            }.store(in: &cancellables)

        uploadedPhotoPublisher
            .sink { [weak self] in
                guard let self else { return }
                guard self.isPerformingBackgroundWork else { return }
                self.isWorkingSubject.send(self.workerState.isWorking)
            }.store(in: &cancellables)
    }

    var isWorkingPublisher: AnyPublisher<Bool, Never> {
        isWorkingSubject.eraseToAnyPublisher()
    }
}
