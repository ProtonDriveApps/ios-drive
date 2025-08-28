// Copyright (c) 2025 Proton AG
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

protocol AddPhotosToAlbumControllerProtocol {
    var isAdding: AnyPublisher<Bool, Never> { get }
    func add(primaryIds: Set<AnyVolumeIdentifier>, to albumId: AnyVolumeIdentifier)
}

final class AddPhotosToAlbumController: AddPhotosToAlbumControllerProtocol {
    private let eventsController: EventsTriggerController
    private let facade: AddPhotosToAlbumFacadeProtocol
    private let messageHandler: AddPhotosToAlbumMessageHandlerProtocol
    private let loadingSubject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    var isAdding: AnyPublisher<Bool, Never> {
        loadingSubject.eraseToAnyPublisher()
    }

    init(eventsController: EventsTriggerController, facade: AddPhotosToAlbumFacadeProtocol, messageHandler: AddPhotosToAlbumMessageHandlerProtocol) {
        self.eventsController = eventsController
        self.facade = facade
        self.messageHandler = messageHandler
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        facade.result
            .sink { [weak self] result in
                self?.handleResult(result)
            }
            .store(in: &cancellables)
    }

    private func handleResult(_ result: AddPhotosToAlbumResult) {
        loadingSubject.send(false)
        switch result {
        case let .success(output):
            handleOutput(output)
        case let .failure(error):
            Log.error("Failed to add photos to album", error: error, domain: .albums)
            messageHandler.handle(error: error)
        }

    }

    private func handleOutput(_ output: AddPhotosToAlbumOutput) {
        eventsController.forcePolling(volumeIDs: [output.volumeId])
        messageHandler.handle(output: output)
    }

    func add(primaryIds: Set<AnyVolumeIdentifier>, to albumId: AnyVolumeIdentifier) {
        guard loadingSubject.value == false else {
            return
        }

        loadingSubject.send(true)
        let input = AddPhotosToAlbumInput(albumId: albumId, primaryPhotoIds: primaryIds)
        facade.execute(with: input)
    }
}
