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

import Foundation
import Combine

final class DispatchedAsyncThumbnailLoader: CancellableThumbnailLoader {
    private let thumbnailLoader: CancellableThumbnailLoader
    private var requestedIds = [ThumbnailLoader.Identifier: WeakReference<BlockOperation>]()
    private let throttlingQueue = OperationQueue(maxConcurrentOperation: 3)

    init(thumbnailLoader: CancellableThumbnailLoader) {
        self.thumbnailLoader = thumbnailLoader
        throttlingQueue.qualityOfService = .userInitiated
    }

    var succeededId: AnyPublisher<Identifier, Never> {
        thumbnailLoader.succeededId
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    var failedId: AnyPublisher<Identifier, Never> {
        thumbnailLoader.failedId
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func loadThumbnail(with id: ThumbnailLoader.Identifier) {
        let operation = makeRequestOperation(with: id)
        throttlingQueue.addOperation(operation)
        requestedIds[id] = WeakReference(reference: operation)
        requestedIds = requestedIds.filter { $0.value.reference != nil }
    }

    func cancelThumbnailLoading(_ id: ThumbnailLoader.Identifier) {
        requestedIds[id]?.reference?.cancel()
        thumbnailLoader.cancelThumbnailLoading(id)
    }

    func cancelAll() {
        requestedIds.values.forEach { $0.reference?.cancel() }
        thumbnailLoader.cancelAll()
    }

    private func makeRequestOperation(with id: ThumbnailLoader.Identifier) -> BlockOperation {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard !(operation?.isCancelled ?? true) else {
                return
            }
            self?.thumbnailLoader.loadThumbnail(with: id)
        }
        return operation
    }
}
