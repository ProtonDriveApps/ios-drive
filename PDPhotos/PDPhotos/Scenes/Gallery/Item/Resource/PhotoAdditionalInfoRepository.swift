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
import CoreData
import Foundation
import PDCore

protocol PhotoAdditionalInfoRepository {
    var info: AnyPublisher<PhotoAdditionalInfo, Never> { get }
    func load(id: PhotoId)
}

final class CoreDataPhotoAdditionalInfoRepository: PhotoAdditionalInfoRepository {
    private let managedObjectContext: NSManagedObjectContext
    private var subject = PassthroughSubject<PhotoAdditionalInfo, Never>()
    private var infos = PhotoAdditionalInfos()

    var info: AnyPublisher<PhotoAdditionalInfo, Never> {
        subject.eraseToAnyPublisher()
    }

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func load(id: PhotoId) {
        managedObjectContext.perform { [weak self] in
            self?.loadFromDatabase(id: id)
        }
    }

    private func loadFromDatabase(id: PhotoId) {
        guard let photo = CoreDataPhoto.fetch(identifier: id, in: managedObjectContext) else {
            return
        }

        let duration = getDuration(from: photo)
        let info = PhotoAdditionalInfo(id: id, duration: duration)
        DispatchQueue.main.async { [weak self] in
            self?.subject.send(info)
        }
    }

    private func getDuration(from photo: Photo) -> UInt? {
        let attributes = try? photo.photoRevision.decryptedExtendedAttributes()
        if let duration = attributes?.media?.duration {
            return UInt(duration)
        } else {
            return nil
        }
    }
}
