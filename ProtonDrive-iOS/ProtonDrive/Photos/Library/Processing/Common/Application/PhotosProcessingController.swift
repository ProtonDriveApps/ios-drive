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

protocol PhotosProcessingController: ErrorController {}

final class ConcretePhotosProcessingController: PhotosProcessingController {
    private let identifiersController: PhotoLibraryIdentifiersController
    private let backupController: PhotosBackupController
    private let availableController: PhotosProcessingAvailableController
    private let processingResource: PhotosProcessingQueueResource
    private let batchAvailableController: PhotosProcessingBatchAvailableController
    private let cleanUpController: CleanUpEventController
    private var cancellables = Set<AnyCancellable>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    private var isProcessing = CurrentValueSubject<Bool, Never>(false)

    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(identifiersController: PhotoLibraryIdentifiersController, backupController: PhotosBackupController, availableController: PhotosProcessingAvailableController, processingResource: PhotosProcessingQueueResource, batchAvailableController: PhotosProcessingBatchAvailableController, cleanUpController: CleanUpEventController) {
        self.identifiersController = identifiersController
        self.backupController = backupController
        self.availableController = availableController
        self.processingResource = processingResource
        self.batchAvailableController = batchAvailableController
        self.cleanUpController = cleanUpController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        subscribeToAvailability()
        subscribeToCancelProcessing()
        subscribeToProcessingEvents()
    }

    private func subscribeToAvailability() {
        availableController.availability
            .removeDuplicates()
            .sink { [weak self] availability in
                switch availability {
                case .full:
                    self?.identifiersController.setFilter(.all)
                    self?.processingResource.resume()
                case .limited:
                    self?.identifiersController.setFilter(.small)
                    self?.processingResource.resume()
                case .none:
                    self?.processingResource.suspend()
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToProcessingEvents() {
        Publishers.CombineLatest3(identifiersController.batch, batchAvailableController.isNextBatchPossible, isProcessing)
            .filter { !$0.0.isEmpty && $0.1 && !$0.2 }
            .map { $0.0 }
            .sink { [weak self] identifiers in
                Log.debug("ConcretePhotosProcessingController processing batch, count: \(identifiers.count)", domain: .photosProcessing)
                self?.isProcessing.send(true)
                self?.processingResource.execute(with: identifiers)
            }
            .store(in: &cancellables)

        processingResource.completion
            .sink { [weak self] context in
                self?.handle(context)
            }
            .store(in: &cancellables)
    }

    private func subscribeToCancelProcessing() {
        let backupDisabledPublisher = backupController.isAvailable
            .filter { $0 == .unavailable }
            .map { _ in Void() }
            .eraseToAnyPublisher()
        Publishers.Merge(backupDisabledPublisher, cleanUpController.updatePublisher)
            .sink { [weak self] _ in
                self?.identifiersController.reset()
                self?.processingResource.cancel()
            }
            .store(in: &cancellables)
    }

    private func handle(_ context: PhotosProcessingContext) {
        identifiersController.complete(unprocessedIdentifiers: Array(context.skippedIdentifiers.union(context.newIdentifiers)))
        if let error = context.errors.first {
            errorSubject.send(error)
        }
        isProcessing.send(false)
    }
}
