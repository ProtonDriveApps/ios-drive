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

final class DatabasePhotoInfoRepository: PhotoInfoRepository {
    private let storage: StorageManager
    private let photoSubject = PassthroughSubject<PhotoInfo, Never>()

    var photo: AnyPublisher<PhotoInfo, Never> {
        photoSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(storage: StorageManager) {
        self.storage = storage
    }

    func execute(with id: PhotoId) {
        storage.backgroundContext.perform {
            guard let photo = self.storage.fetchPhoto(id: id, moc: self.storage.backgroundContext) else {
                return
            }

            let photoInfo = PhotoInfo(id: id, name: photo.decryptedName)
            self.photoSubject.send(photoInfo)
        }
    }
}
