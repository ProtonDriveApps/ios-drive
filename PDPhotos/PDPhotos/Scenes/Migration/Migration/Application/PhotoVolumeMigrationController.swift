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

public enum PhotoVolumeMigrationState: Equatable {
    case undetermined
    case inProgress
    case finished
}

public protocol PhotoVolumeMigrationControllerProtocol: ErrorController {
    var state: AnyPublisher<PhotoVolumeMigrationState, Never> { get }
    /// Starts migration on BE then continues to monitor the process
    func startMigration()
    /// Invoke when migration is already happening, will clean up local state and then monitor the process
    func monitorMigration()
}

// Starts and monitors migration to photo volume in BE. Doesn't bootstrap the new volume after finishing.
final class PhotoVolumeMigrationController: PhotoVolumeMigrationControllerProtocol {
    private let startFacade: PhotoVolumeMigrationStartFacade
    private let updateFacade: PhotoVolumeMigrationUpdateFacade
    private var stateSubject = CurrentValueSubject<PhotoVolumeMigrationState, Never>(.undetermined)
    private let errorSubject = PassthroughSubject<Error, Never>()
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<PhotoVolumeMigrationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(startFacade: PhotoVolumeMigrationStartFacade, updateFacade: PhotoVolumeMigrationUpdateFacade) {
        self.startFacade = startFacade
        self.updateFacade = updateFacade
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        startFacade.result
            .sink { [weak self] result in
                self?.handleStart(result)
            }
            .store(in: &cancellables)

        updateFacade.result
            .sink { [weak self] result in
                self?.handleUpdate(result)
            }
            .store(in: &cancellables)
    }

    private func handleStart(_ result: PhotoVolumeMigrationStartResult) {
        switch result {
        case .success:
            updateFacade.startObserving()
        case let .failure(error):
            errorSubject.send(error)
        }
    }

    private func handleUpdate(_ result: PhotoVolumeMigrationUpdateResult) {
        switch result {
        case .success:
            stateSubject.send(.finished)
        case let .failure(error):
            errorSubject.send(error)
        }
    }

    func startMigration() {
        start(with: .fullStart)
    }

    func monitorMigration() {
        start(with: .skipRemote)
    }

    private func start(with input: PhotoVolumeMigrationStartInput) {
        stateSubject.send(.inProgress)
        startFacade.execute(with: input)
    }
}
