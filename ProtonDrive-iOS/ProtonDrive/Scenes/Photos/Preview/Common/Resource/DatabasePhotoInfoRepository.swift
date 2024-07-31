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

import CoreData
import Combine
import Foundation
import PDCore

final class DatabasePhotoInfoRepository: PhotoInfoRepository {
    private let storage: StorageManager
    private let photoSubject = PassthroughSubject<PhotoInfo, Never>()
    private let managedObjectContext: NSManagedObjectContext

    var photo: AnyPublisher<PhotoInfo, Never> {
        photoSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(storage: StorageManager) {
        self.storage = storage
        managedObjectContext = storage.newBackgroundContext()
    }

    func execute(with id: PhotoId) {
        managedObjectContext.perform { [weak self] in
            guard let self, let photo = try? self.storage.fetchPhoto(id: id, moc: self.managedObjectContext) else {
                return
            }

            let mimeType = MimeType(value: photo.mimeType)
            let type: PhotoInfo.PhotoType
            if mimeType.isVideo {
                type = .video
            } else if mimeType.isGif {
                type = .gif
            } else {
                type = .photo
            }
            let photoInfo = PhotoInfo(id: id, name: photo.decryptedName, type: type)
            self.photoSubject.send(photoInfo)
        }
    }
}
