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
import PDCore

protocol PhotosPagingLoadController: AnyObject {
    func loadNext()
}

final class RemotePhotosPagingLoadController: PhotosPagingLoadController {
    private let backupController: PhotosBackupUploadAvailableController
    private let interactor: PhotosFullLoadInteractor
    private var cancellables = Set<AnyCancellable>()
    private var currentId: PhotosListLoadId?
    private var lastId: PhotosListLoadId?

    init(backupController: PhotosBackupUploadAvailableController, interactor: PhotosFullLoadInteractor) {
        self.interactor = interactor
        self.backupController = backupController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        interactor.result
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)

        backupController.isAvailable
            .filter { [weak self] isAvailable in
                self?.currentId == nil && isAvailable
            }
            .sink { [weak self] _ in
                self?.loadNext()
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: PhotoIdsResult) {
        switch result {
        case let .success(ids):
            if let id = ids.last {
                lastId = PhotosListLoadId(photoId: id)
            }
        case let .failure(error):
            // TODO: next MR handle errors
            break
        }
    }

    func loadNext() {
        let id = lastId ?? PhotosListLoadId(photoId: nil)

        guard id != currentId else {
            return
        }

        interactor.execute(with: id)
        currentId = id
    }
}
