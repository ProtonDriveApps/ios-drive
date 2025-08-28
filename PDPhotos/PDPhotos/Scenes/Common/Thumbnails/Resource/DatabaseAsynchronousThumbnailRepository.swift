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

enum AsynchronousThumbnailRepositoryError: Error {
    case dataUnavailable
}

enum ThumbnailLoadResult {
    case data(Data)
    case encrypted
    case missingURL
    case missingMetadata
}

final class DatabaseAsynchronousThumbnailRepository: AsynchronousThumbnailRepository {
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager
    private let type: ThumbnailType
    private let subject = PassthroughSubject<ThumbnailLoadResult, Never>()
    private var task: Task<Void, Never>?

    var result: AnyPublisher<ThumbnailLoadResult, Never> {
        subject.eraseToAnyPublisher()
    }

    init(managedObjectContext: NSManagedObjectContext, storageManager: StorageManager, type: ThumbnailType) {
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
        self.type = type
    }

    deinit {
        cancel()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func load(id: PhotoId) {
        guard task == nil else {
            return
        }

        task = Task { [weak self] in
            guard !Task.isCancelled else {
                return
            }
            await self?.loadAsynchronously(id: id)
        }
    }

    private func loadAsynchronously(id: PhotoId) async {
        let optionalResult: ThumbnailLoadResult? = await managedObjectContext.perform { [weak self] in
            guard !Task.isCancelled else {
                return nil
            }
            guard let thumbnail = self?.getThumbnail(id: id) else {
                return ThumbnailLoadResult.missingMetadata
            }
            if let data = thumbnail.clearThumbnail {
                return ThumbnailLoadResult.data(data)
            } else if thumbnail.encrypted != nil {
                return ThumbnailLoadResult.encrypted
            } else {
                return ThumbnailLoadResult.missingURL
            }
        }
        if let result = optionalResult {
            await finish(with: result)
        }
    }

    private func getThumbnail(id: PhotoId) -> Thumbnail? {
        let photo = Photo.fetch(identifier: id, in: managedObjectContext)
        return photo?.photoRevision.thumbnails.first(where: { $0.type == type })
    }

    @MainActor
    private func finish(with result: ThumbnailLoadResult) {
        subject.send(result)
        task = nil
    }

    private func makeResult(from data: Data?) -> Result<Data, Error> {
        if let data {
            return .success(data)
        } else {
            return .failure(AsynchronousThumbnailRepositoryError.dataUnavailable)
        }
    }
}
