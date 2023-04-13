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
import os.log
import PDCore

typealias URLResult = Result<URL, Error>

protocol PhotoPickerLoadResource {
    var resultsPublisher: AnyPublisher<[URLResult], Never> { get }
    func set(itemProviders: [NSItemProvider])
}

final class PhotoPickerResource: PickerResource, PhotoPickerLoadResource {
    private let resource: ItemProviderLoadResource
    private let queue: OperationQueue
    private var results = [URLResult]()
    private let resultsSubject = PassthroughSubject<[URLResult], Never>()

    let resultsPublisher: AnyPublisher<[URLResult], Never>
    let updatePublisher: AnyPublisher<Void, Never>
    var isExecuting: Bool = false

    init(resource: ItemProviderLoadResource) {
        self.resource = resource
        queue = OperationQueue()
        // We might try running imports in parallel to speed up this stage.
        // Need to investigate memory constraints.
        queue.maxConcurrentOperationCount = 1
        queue.isSuspended = true
        queue.qualityOfService = .userInitiated

        resultsPublisher = resultsSubject.eraseToAnyPublisher()
        updatePublisher = resultsSubject
            .map { _ in Void() }
            .eraseToAnyPublisher()
    }

    func start() {
        queue.isSuspended = false
    }

    func cancel() {
        queue.isSuspended = true
    }

    func set(itemProviders: [NSItemProvider]) {
        isExecuting = true
        let operations = itemProviders.map(makeOperation)
        queue.addOperations(operations, waitUntilFinished: false)
        queue.addBarrierBlock { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        let results = results
        self.results.removeAll()
        isExecuting = false
        resultsSubject.send(results)
    }

    private func makeOperation(with itemProvider: NSItemProvider) -> Operation {
        return ItemProviderLoadOperation(resource: resource, itemProvider: itemProvider) { [weak self] result in
            self?.results.append(result)
        }
    }
}
