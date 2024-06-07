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

protocol PhotosProcessingQueueResource {
    var completion: AnyPublisher<PhotosProcessingContext, Never> { get }
    func execute(with identifiers: Set<PhotoIdentifier>)
    func suspend()
    func resume()
    func cancel()
}

final class ConcretePhotosProcessingQueueResource: PhotosProcessingQueueResource {
    private let factory: PhotosProcessingOperationsFactory
    private let queue: OperationQueue
    private let subject = PassthroughSubject<PhotosProcessingContext, Never>()

    var completion: AnyPublisher<PhotosProcessingContext, Never> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(factory: PhotosProcessingOperationsFactory) {
        self.factory = factory
        queue = OperationQueue(maxConcurrentOperation: 1, underlyingQueue: DispatchQueue(label: "ConcretePhotosProcessingQueueResourceQueue"))
    }

    func execute(with identifiers: Set<PhotoIdentifier>) {
        if queue.operationCount != 0 {
            assertionFailure("Only one set of operations at a time, please.")
        }
        let context = factory.makeContext(with: identifiers)
        let operations = factory.makeOperations(with: context)
        queue.addOperations(operations, waitUntilFinished: false)
        queue.addBarrierBlock { [weak self] in
            self?.subject.send(context)
        }
    }

    func suspend() {
        Log.debug("ConcretePhotosProcessingQueueResource suspended", domain: .photosProcessing)
        queue.isSuspended = true
    }

    func resume() {
        Log.debug("ConcretePhotosProcessingQueueResource resumed", domain: .photosProcessing)
        queue.isSuspended = false
    }

    func cancel() {
        Log.debug("ConcretePhotosProcessingQueueResource cancelled", domain: .photosProcessing)
        queue.cancelAllOperations()
    }
}
