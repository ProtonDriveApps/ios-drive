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
import ProtonCoreNetworking

enum RemotePhotoLoadStatus {
    case undetermined
    case hasBackedUpPhoto
    case withoutBackedUpPhoto
    case failure
    case disconnected
    
    var hasBackedUpPhoto: Bool {
        switch self {
        case .hasBackedUpPhoto: return true
        default: return false
        }
    }
}

protocol PhotosPagingLoadController: AnyObject, ErrorController {
    func loadNext()
    func loadNextIfNeeded(captureTime: Date)
    
    var loadStatus: AnyPublisher<RemotePhotoLoadStatus, Never> { get }
}

final class RemotePhotosPagingLoadController: PhotosPagingLoadController {
    private let bootstrapController: PhotosBootstrapController
    private let interactor: PhotosFullLoadInteractor
    private var cancellables = Set<AnyCancellable>()
    private var currentId: PhotosListLoadId?
    private var lastId: PhotosListLoadId?
    private var captureTimeThreshold: Date?
    private var errorSubject = PassthroughSubject<Error, Never>()
    private var linkIdsCanFetchNext: [String] = []
    private var photoLoadStatusSubject = PassthroughSubject<RemotePhotoLoadStatus, Never>()
    private var isBootstrapped = false
    private var status: RemotePhotoLoadStatus = .undetermined {
        didSet { photoLoadStatusSubject.send(status) }
    }

    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    var loadStatus: AnyPublisher<RemotePhotoLoadStatus, Never> {
        photoLoadStatusSubject.eraseToAnyPublisher()
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
            .removeDuplicates()
            .sink { [weak self] isReady in
                if isReady {
                    self?.isBootstrapped = true
                    self?.loadNext()
                }
            }
            .store(in: &cancellables)
        
        bootstrapController.errorPublisher
            .sink { [weak self] error in
                self?.status = error.isNetworkIssueError ? .disconnected : .failure
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: PhotoIdsResult) {
        switch result {
        case let .success(response):
            handleSuccess(response)

            let withoutPhoto = response.lastItem == nil && currentId?.photoId == nil
            status = withoutPhoto ? .withoutBackedUpPhoto : .hasBackedUpPhoto
        case let .failure(error):
            currentId = nil
            errorSubject.send(error)
            Log.error(error, domain: .photosProcessing)
            status = error.isNetworkIssueError ? .disconnected : .failure
        }
    }

    private func handleSuccess(_ response: PhotosLoadResponse) {
        guard let lastItem = response.lastItem else { return }
        
        lastId = PhotosListLoadId(photoId: lastItem.id)
        captureTimeThreshold = response.captureTimeThreshold
        Log.info("PhotosPagingLoadController.handleSuccess", domain: .photosProcessing)
    }

    func loadNext() {
        guard isBootstrapped else {
            bootstrapController.bootstrap()
            return
        }

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
        guard let captureTimeThreshold else { return }

        if captureTime <= captureTimeThreshold {
            Log.info("PhotosPagingLoadController.loadNextIfNeeded, compared dates: \(captureTime), \(captureTimeThreshold)", domain: .photosProcessing)
            loadNext()
        }
    }
}
