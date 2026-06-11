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

final class ConcretePhotosProcessingController: PhotosProcessingController {
    private let identifiersController: PhotoLibraryIdentifiersController
    private let backupController: PhotosBackupController
    private let availableController: PhotosProcessingAvailableController
    private let processingResource: PhotosProcessingQueueResource
    private let cleanUpController: CleanUpEventController
    private var cancellables = Set<AnyCancellable>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    private var isProcessing = CurrentValueSubject<Bool, Never>(false)
    private var retryCount: [PhotoIdentifier: Int] = [:]
    private let failedIdentifiersResource: DeletedPhotosIdentifierStoreResource
    private let progressRepository: PhotoLibraryLoadProgressRepository

    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(
        identifiersController: PhotoLibraryIdentifiersController,
        backupController: PhotosBackupController,
        availableController: PhotosProcessingAvailableController,
        processingResource: PhotosProcessingQueueResource,
        cleanUpController: CleanUpEventController,
        failedIdentifiersResource: DeletedPhotosIdentifierStoreResource,
        progressRepository: PhotoLibraryLoadProgressRepository
    ) {
        self.identifiersController = identifiersController
        self.backupController = backupController
        self.availableController = availableController
        self.processingResource = processingResource
        self.cleanUpController = cleanUpController
        self.failedIdentifiersResource = failedIdentifiersResource
        self.progressRepository = progressRepository
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
        Publishers.CombineLatest(identifiersController.batch, isProcessing)
            .filter { !$0.0.isEmpty && !$0.1 }
            .map { $0.0 }
            .sink { [weak self] identifiers in
                Log.debug("Processing batch, count: \(identifiers.count)", domain: .photosProcessing)
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
        handleRetryIdentifiers(from: context)
        if let error = context.errors.first {
            errorSubject.send(error)
        }
        isProcessing.send(false)
    }

    /// Filter retryable identifiers
    /// Some photos may encounter temporary issues in the `PhotosAssetsInteractor`, such as storage or network problems.
    /// These failed identifiers can be retried, but each one is allowed a maximum of 3 attempts (including the initial try).
    /// After 3 failed attempts, the identifier is added to `failedIdentifiers`, allowing the user to choose whether to skip or retry it.
    private func handleRetryIdentifiers(from context: PhotosProcessingContext) {
        var retryIdentifiers: Set<PhotoIdentifier> = []
        var failedCount = 0
        for (id, error) in context.skippedIdentifiersAndError {
            var count = retryCount[id] ?? 1
            count += 1
            if count > 3 {
                retryCount[id] = nil
                failedIdentifiersResource.increment(cloudIdentifier: id.cloudIdentifier, error: error)
                failedCount += 1
            } else {
                retryCount[id] = count
                retryIdentifiers.insert(id)
            }
        }

        identifiersController.complete(unprocessedIdentifiers: Array(retryIdentifiers.union(context.newIdentifiers)))
        progressRepository.discard(failedCount)
    }
}
