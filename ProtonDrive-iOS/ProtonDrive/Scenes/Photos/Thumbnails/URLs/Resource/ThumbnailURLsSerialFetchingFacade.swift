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

import Foundation
import Combine
import PDCore

final class ThumbnailURLsSerialFetchingFacade: ThumbnailURLsFetchingFacade {
    private let interactor: ThumbnailURLsInteractor
    private let input = PassthroughSubject<PhotoIdsSet, Never>()
    private let output = PassthroughSubject<PhotoIdsSet, Never>()
    private let serialQueue = OperationQueue(maxConcurrentOperation: 1)
    private var cancellables = Set<AnyCancellable>()

    var finished: AnyPublisher<PhotoIdsSet, Never> {
        output.eraseToAnyPublisher()
    }

    init(interactor: ThumbnailURLsInteractor) {
        self.interactor = interactor
        subscribeToUpdates()
    }

    func execute(ids: PhotoIdsSet) {
        /// Input is debounced in order not to overuse BE's apis.
        input.send(ids)
    }

    private func subscribeToUpdates() {
        input
            .debounce(for: .milliseconds(100), scheduler: serialQueue)
            .sink { [weak self] ids in
                self?.addOperation(ids)
            }
            .store(in: &cancellables)
    }

    private func addOperation(_ ids: PhotoIdsSet) {
        /// We want to fetch only latest set, so cancel all queued operations.
        /// Already running operation will be finished
        serialQueue.cancelAllOperations()
        let operation = makeOperation(ids: ids)
        serialQueue.addOperation(operation)
    }

    private func makeOperation(ids: PhotoIdsSet) -> Operation {
        AsynchronousBlockOperation { [weak self] in
            await self?.executeAsynchronously(ids: ids)
        }
    }

    private func executeAsynchronously(ids: PhotoIdsSet) async {
        try? await interactor.execute(ids: ids)
        await MainActor.run { [weak self] in
            self?.output.send(ids)
        }
    }
}
