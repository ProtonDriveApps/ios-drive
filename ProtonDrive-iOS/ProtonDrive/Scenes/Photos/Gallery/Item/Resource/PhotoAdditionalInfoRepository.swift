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
    private var subject = PassthroughSubject<PhotoAdditionalInfo, Never>()
    private let observer: FetchedResultsSectionsController<Photo>
    private let queue = DispatchQueue(label: "PhotoAdditionalInfoRepository", qos: .default, attributes: .concurrent)
    private var infos = PhotoAdditionalInfos()

    var info: AnyPublisher<PhotoAdditionalInfo, Never> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(observer: FetchedResultsSectionsController<Photo>) {
        self.observer = observer
    }

    func load(id: PhotoId) {
        observer.managedObjectContext.perform { [weak self] in
            self?.loadFromObserver(id: id)
        }
    }

    private func loadFromObserver(id: PhotoId) {
        guard let photo = observer.getObjects().first(where: { $0.identifier == id }) else {
            return
        }

        let duration = getDuration(from: photo)
        let info = PhotoAdditionalInfo(id: id, duration: duration)
        queue.async { [weak self] in
            self?.subject.send(info)
        }
    }

    private func loadInfo(id: PhotoId, photo: Photo) -> PhotoAdditionalInfo? {
        let duration = getDuration(from: photo)
        return PhotoAdditionalInfo(id: id, duration: duration)
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
