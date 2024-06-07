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

struct PhotosLoadResponse: Equatable {
    struct Item: Equatable {
        let id: PhotoListId
        let captureTime: Date
        let isLastLocally: Bool
    }

    let lastItem: Item?
}

typealias PhotoListId = String
typealias PhotoIdsResult = Result<PhotosLoadResponse, Error>

protocol PhotosFullLoadInteractor {
    var result: AnyPublisher<PhotoIdsResult, Never> { get }
    func execute(with id: PhotosListLoadId)
}

final class RemotePhotosFullLoadInteractor: PhotosFullLoadInteractor {
    private let listInteractor: PhotosListLoadResultInteractor
    private let metadataInteractor: PhotosMetadataLoadResultInteractor
    private let subject = PassthroughSubject<PhotoIdsResult, Never>()
    private var cancellables = Set<AnyCancellable>()

    var result: AnyPublisher<PhotoIdsResult, Never> {
        subject.eraseToAnyPublisher()
    }

    init(listInteractor: PhotosListLoadResultInteractor, metadataInteractor: PhotosMetadataLoadResultInteractor) {
        self.listInteractor = listInteractor
        self.metadataInteractor = metadataInteractor
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        listInteractor.result
            .sink { [weak self] result in
                self?.handleList(result)
            }
            .store(in: &cancellables)

        metadataInteractor.result
            .sink { [weak self] result in
                self?.subject.send(result)
            }
            .store(in: &cancellables)
    }

    private func handleList(_ result: PhotosListLoadResult) {
        switch result {
        case let .success(list):
            if list.photos.isEmpty {
                let response = PhotosLoadResponse(lastItem: nil)
                subject.send(.success(response))
            } else {
                metadataInteractor.execute(with: list)
            }
        case let .failure(error):
            subject.send(.failure(error))
        }
    }

    func execute(with id: PhotosListLoadId) {
        listInteractor.execute(with: id)
    }
}
