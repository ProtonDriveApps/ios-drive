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

import PDCore
import Combine
import Foundation

protocol PhotoLibraryAssetsQueueResource {
    var results: AnyPublisher<PhotoAssetCompoundsResult, Never> { get }
    func execute(with identifiers: PhotoIdentifiers)
    func isExecuting() -> Bool
    func start() throws
    func cancel()
    func update(isConstrained: Bool)
}

enum LocalPhotoLibraryAssetsQueueResourceError: Error {
    case emptyQueue
}

final class LocalPhotoLibraryAssetsQueueResource: PhotoLibraryAssetsQueueResource {
    private let resource: PhotoLibraryAssetsResource
    private let queue: OperationQueue
    private let resultsSubject = PassthroughSubject<PhotoAssetCompoundsResult, Never>()
    private var identifiersInProgress = Set<PhotoIdentifier>()

    var results: AnyPublisher<PhotoAssetCompoundsResult, Never> {
        resultsSubject.eraseToAnyPublisher()
    }

    init(resource: PhotoLibraryAssetsResource) {
        self.resource = resource
        queue = OperationQueue(maxConcurrentOperation: Constants.photosAssetsParalelProcessingCount, isSuspended: false)
        queue.qualityOfService = .background
    }

    func start() throws {
        guard isExecuting() else {
            throw LocalPhotoLibraryAssetsQueueResourceError.emptyQueue
        }
        queue.isSuspended = false
    }

    func cancel() {
        queue.isSuspended = true
    }

    func isExecuting() -> Bool {
        return !identifiersInProgress.isEmpty && !queue.isSuspended
    }

    func execute(with identifiers: PhotoIdentifiers) {
        let operations = identifiers.map(makeOperation)
        identifiersInProgress.formUnion(identifiers)
        queue.addOperations(operations, waitUntilFinished: false)
    }

    func update(isConstrained: Bool) {
        queue.isSuspended = isConstrained
    }

    private func makeOperation(with identifier: PhotoIdentifier) -> Operation {
        return PhotoLibraryAssetsOperation(resource: resource, identifier: identifier) { [weak self] result in
            self?.handle(result, identifier: identifier)
        }
    }

    private func handle(_ result: PhotoAssetCompoundsResult, identifier: PhotoIdentifier) {
        identifiersInProgress.remove(identifier)
        resultsSubject.send(result)
    }
}
