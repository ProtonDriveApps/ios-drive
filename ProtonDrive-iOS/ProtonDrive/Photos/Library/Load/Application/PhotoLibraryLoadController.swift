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
import Foundation
import PDCore
import PDPhotos

protocol PhotoLibraryLoadController {
    var isLoading: AnyPublisher<Bool, Never> { get }
    func getInitialCount() -> Int?
    func handlePrematureCompletion()
}

final class LocalPhotoLibraryLoadController: PhotoLibraryLoadController {
    private let backupController: PhotosBackupController
    private let identifiersController: PhotoLibraryIdentifiersController
    private let computationalAvailabilityController: ComputationalAvailabilityController
    private let interactor: PhotoLibraryLoadInteractor
    private var isProcessing = false
    private var loadingSubject = CurrentValueSubject<Bool, Never>(false)
    private var delayedPublisher = PassthroughSubject<Void, Never>()
    private let scheduler: AnySchedulerOf<DispatchQueue>
    private var cancellables = Set<AnyCancellable>()
    private var count: Int?

    private var loadingResetCancellable: AnyCancellable?

    var isLoading: AnyPublisher<Bool, Never> {
        loadingSubject.eraseToAnyPublisher()
    }

    init(backupController: PhotosBackupController, identifiersController: PhotoLibraryIdentifiersController, computationalAvailabilityController: ComputationalAvailabilityController, interactor: PhotoLibraryLoadInteractor, scheduler: AnySchedulerOf<DispatchQueue>) {
        self.backupController = backupController
        self.identifiersController = identifiersController
        self.computationalAvailabilityController = computationalAvailabilityController
        self.interactor = interactor
        self.scheduler = scheduler
        subscribeToUpdates()
    }

    func getInitialCount() -> Int? {
        count
    }

    private func subscribeToUpdates() {
        backupController.isAvailable
            .removeDuplicates()
            .sink { [weak self] availability in
                self?.handleUpdate(availability: availability)
            }
            .store(in: &cancellables)

        computationalAvailabilityController.availability
            .sink { [weak self] availability in
                self?.handleComputationalAvailability(availability)
            }
            .store(in: &cancellables)

        interactor.identifiers
            .sink { [weak self] update in
                self?.handleIdentifiers(update: update)
            }
            .store(in: &cancellables)
    }

    private func scheduleLoadingEnd(with delay: Double) {
        guard loadingResetCancellable == nil else {
            return
        }

        loadingResetCancellable = Just(false)
            .delay(for: .seconds(delay), scheduler: scheduler)
            .handleEvents(receiveCompletion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.loadingResetCancellable = nil
            })
            .sink { [weak self] value in
                self?.loadingSubject.send(value)
            }
    }

    private func handleIdentifiers(update: PhotoLibraryLoadUpdate) {
        let identifiers = update.identifiers
        if !identifiers.isEmpty {
            identifiersController.add(ids: identifiers)
        }

        switch update {
        case .fullLoad:
            count = identifiers.count
            let delay = Double(count ?? 0) * 0.01 // 1 second per every 100 identifiers
            scheduleLoadingEnd(with: delay)
        case .loading:
            loadingResetCancellable?.cancel()
            loadingSubject.send(true)
        case .update:
            break
        }
    }

    func handlePrematureCompletion() {
        guard loadingResetCancellable != nil else {
            return
        }
        loadingResetCancellable = nil
        loadingSubject.send(false)
    }

    private func handleUpdate(availability: PhotosBackupAvailability) {
        switch availability {
        case .available:
            executeInteractor()
        case .locked:
            break
        case .unavailable:
            cancelInteractor()
        }
    }

    private func executeInteractor() {
        if !isProcessing {
            isProcessing = true
            loadingResetCancellable?.cancel()
            loadingSubject.send(true)
            interactor.execute()
        }
    }

    private func cancelInteractor() {
        isProcessing = false
        loadingResetCancellable?.cancel()
        loadingSubject.send(false)
        interactor.cancel()
    }

    private func handleComputationalAvailability(_ availability: ComputationalAvailability) {
        switch availability {
        case .suspended, .extensionTask: // Intentionally suspending in extension, which is shortlived
            interactor.suspend()
        case .foreground, .processingTask:
            interactor.resume()
        }
    }
}
