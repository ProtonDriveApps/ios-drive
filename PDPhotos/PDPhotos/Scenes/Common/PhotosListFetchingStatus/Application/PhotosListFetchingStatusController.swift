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

enum PhotosListFetchingStatus: Equatable {
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

protocol PhotosListFetchingStatusControllerProtocol {
    var status: AnyPublisher<PhotosListFetchingStatus, Never> { get }
}

final class PhotosListFetchingStatusController: PhotosListFetchingStatusControllerProtocol {
    private let fetchingController: PhotosListFetchingControllerProtocol
    private var subject = CurrentValueSubject<PhotosListFetchingStatus, Never>(.undetermined)
    private var cancellables = Set<AnyCancellable>()

    var status: AnyPublisher<PhotosListFetchingStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    init(fetchingController: PhotosListFetchingControllerProtocol) {
        self.fetchingController = fetchingController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        fetchingController.errorPublisher
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)

        fetchingController.lastAnchor
            .sink { [weak self] anchor in
                self?.handleResponse(anchor)
            }
            .store(in: &cancellables)

        fetchingController.firstLoad
            .sink { [weak self] in
                self?.subject.send(.undetermined)
            }
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error) {
        if error.isNetworkIssueError {
            subject.send(.disconnected)
        } else {
            subject.send(.failure)
        }
    }

    private func handleResponse(_ anchor: PhotosListFetchingAnchor) {
        if anchor.hasPhotos {
            subject.send(.hasBackedUpPhoto)
        } else {
            subject.send(.withoutBackedUpPhoto)
        }
    }
}
