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

protocol PhotosPagingLoadController: AnyObject, ErrorController {
    func loadNext()
    func loadNextIfNeeded(captureTime: Date)
}

final class RemotePhotosPagingLoadController: PhotosPagingLoadController {
    private let bootstrapController: PhotosBootstrapController
    private let interactor: PhotosFullLoadInteractor
    private var cancellables = Set<AnyCancellable>()
    private var currentId: PhotosListLoadId?
    private var lastId: PhotosListLoadId?
    private var lastCaptureTime: Date?
    private var errorSubject = PassthroughSubject<Error, Never>()

    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(bootstrapController: PhotosBootstrapController, interactor: PhotosFullLoadInteractor) {
        self.bootstrapController = bootstrapController
        self.interactor = interactor
        subscribeToUpdates()
        bootstrapController.bootstrap()
    }

    private func subscribeToUpdates() {
        interactor.result
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)

        bootstrapController.isReady
            .sink { [weak self] isReady in
                if isReady {
                    self?.loadNext()
                }
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: PhotoIdsResult) {
        switch result {
        case let .success(response):
            handleSuccess(response)
        case let .failure(error):
            currentId = nil
            errorSubject.send(error)
            Log.error(error, domain: .photosProcessing)
        }
    }

    private func handleSuccess(_ response: PhotosLoadResponse) {
        guard let lastItem = response.lastItem else { return }

        lastId = PhotosListLoadId(photoId: lastItem.id)
        lastCaptureTime = lastItem.captureTime
        if !lastItem.isLastLocally {
            // If there're more items locally than fetched items, we want to fetch next pages so the user has all adjacent photos in their grid.
            Log.info("PhotosPagingLoadController.handleSuccess, more items needed to fetch.", domain: .photosProcessing)
            loadNext()
        }
    }

    func loadNext() {
        let id = lastId ?? PhotosListLoadId(photoId: nil)

        guard id != currentId else {
            return
        }

        Log.info("PhotosPagingLoadController.loadNext, id: \(id.photoId ?? "empty")", domain: .photosProcessing)
        interactor.execute(with: id)
        currentId = id
    }

    func loadNextIfNeeded(captureTime: Date) {
        // Scrolling past the last fetched photo (photos are ordered by capture time descending)
        guard let lastCaptureTime else { return }

        if captureTime <= lastCaptureTime {
            Log.info("PhotosPagingLoadController.loadNextIfNeeded, compared dates: \(captureTime), \(lastCaptureTime)", domain: .photosProcessing)
            loadNext()
        }
    }
}
