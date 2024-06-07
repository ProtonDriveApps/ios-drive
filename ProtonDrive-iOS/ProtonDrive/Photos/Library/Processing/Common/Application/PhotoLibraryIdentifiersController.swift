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

protocol PhotoLibraryIdentifiersController {
    var batch: AnyPublisher<Set<PhotoIdentifier>, Never> { get }
    func add(ids: PhotoIdentifiers)
    func complete(unprocessedIdentifiers: PhotoIdentifiers)
    func reset()
    func setFilter(_ filter: PhotoLibraryIdentifiersFilter)
}

enum PhotoLibraryIdentifiersFilter {
    case all
    case small
}

final class ConcretePhotoLibraryIdentifiersController: PhotoLibraryIdentifiersController {
    private let progressController: PhotoLibraryLoadProgressController
    private var repository: RemainingPhotoIdentifiersRepository
    private let identifiersQueueRepository: PhotoLibraryIdentifiersQueueRepository
    private var currentBatch = CurrentValueSubject<Set<PhotoIdentifier>, Never>([])

    init(progressController: PhotoLibraryLoadProgressController, repository: RemainingPhotoIdentifiersRepository, identifiersQueueRepository: PhotoLibraryIdentifiersQueueRepository) {
        self.progressController = progressController
        self.repository = repository
        self.identifiersQueueRepository = identifiersQueueRepository
    }

    var batch: AnyPublisher<Set<PhotoIdentifier>, Never> {
        currentBatch.eraseToAnyPublisher()
    }

    func add(ids: PhotoIdentifiers) {
        Log.debug("ConcretePhotoLibraryIdentifiersController.add", domain: .photosProcessing)
        repository.insert(ids)
        progressController.handle(.added(ids.count))
        executeNextBatchIfPossible()
    }

    func complete(unprocessedIdentifiers: PhotoIdentifiers) {
        Log.debug("ConcretePhotoLibraryIdentifiersController.complete", domain: .photosProcessing)
        repository.insert(unprocessedIdentifiers)
        currentBatch.value.removeAll()
        executeNextBatchIfPossible()
    }

    func reset() {
        Log.debug("ConcretePhotoLibraryIdentifiersController.reset", domain: .photosProcessing)
        repository.removeAll()
        currentBatch.send([])
        progressController.handle(.reset)
    }

    func setFilter(_ filter: PhotoLibraryIdentifiersFilter) {
        Log.debug("ConcretePhotoLibraryIdentifiersController.setFilter", domain: .photosProcessing)
        repository.setFilter(filter)
        executeNextBatchIfPossible()
    }

    private func executeNextBatchIfPossible() {
        guard repository.hasNext() else {
            return
        }
        guard currentBatch.value.isEmpty else {
            return
        }
        executeNextBatch()
    }

    private func executeNextBatch() {
        let batch = repository.subtractNext()
        let remainingIdentifiers = repository.getAll()
        identifiersQueueRepository.set(identifiers: remainingIdentifiers)

        // There might be same identifiers added to the queue due to postprocessing done by Apple.
        // We will be able to process only the latest binaries, so we need to exclude the duplicates count from progress (as they were already included).
        let batchSet = Set(batch)
        let duplicatesCount = batch.count - batchSet.count
        if duplicatesCount > 0 {
            progressController.handle(.discarded(duplicatesCount))
        }

        Log.debug("ConcretePhotoLibraryIdentifiersController.executeNextBatch: batchSetCount: \(batchSet.count), remaining: \(remainingIdentifiers.count)", domain: .photosProcessing)
        currentBatch.send(batchSet)
    }
}

extension ConcretePhotoLibraryIdentifiersController: WorkerState {
    var isWorking: Bool {
        !currentBatch.value.isEmpty || repository.hasNext()
    }
}
