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

final class PhotoLibraryAssetsOperationInteractor: OperationInteractor {
    private let resource: PhotoLibraryAssetsQueueResource
    private let errorSubject = PassthroughSubject<Void, Never>()

    init(resource: PhotoLibraryAssetsQueueResource) {
        self.resource = resource
    }

    var updatePublisher: AnyPublisher<Void, Never> {
        let resourcePublisher = resource.results.map { _ in Void() }
        return Publishers.Merge(resourcePublisher, errorSubject).eraseToAnyPublisher()
    }

    var state: OperationInteractorState {
        resource.isExecuting() ? .running : .idle
    }

    func start() {
        do {
            try resource.start()
        } catch {
            errorSubject.send()
        }
    }

    func cancel() {
        resource.cancel()
    }
}
