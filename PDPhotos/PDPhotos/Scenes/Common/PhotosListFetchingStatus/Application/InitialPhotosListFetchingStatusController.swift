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

// Only observing first status update to indicate first load after app starts and then stops observing
// to avoid confusion with subsequent loads. It's used by determining if user has any photos on remote.
final class InitialPhotosListFetchingStatusController: PhotosListFetchingStatusControllerProtocol {
    private let statusController: PhotosListFetchingStatusControllerProtocol
    private var subject = CurrentValueSubject<PhotosListFetchingStatus, Never>(.undetermined)
    private var cancellables = Set<AnyCancellable>()

    var status: AnyPublisher<PhotosListFetchingStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    init(statusController: PhotosListFetchingStatusControllerProtocol) {
        self.statusController = statusController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        statusController.status
            .sink { [weak self] status in
                self?.handleStatus(status)
            }
            .store(in: &cancellables)
    }

    private func handleStatus(_ status: PhotosListFetchingStatus) {
        subject.send(status)

        if status == .withoutBackedUpPhoto || status == .hasBackedUpPhoto {
            cancellables.removeAll()
        }
    }
}
