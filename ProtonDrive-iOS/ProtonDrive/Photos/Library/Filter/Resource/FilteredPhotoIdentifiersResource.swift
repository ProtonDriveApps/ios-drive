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
import PDCore

protocol FilteredPhotoIdentifiersResource {
    var result: AnyPublisher<[PhotoIdentifier], Never> { get }
    func execute(with identifiers: [PhotoIdentifier])
}

final class DatabaseFilteredPhotoIdentifiersResource: FilteredPhotoIdentifiersResource {
    private let storage: StorageManager
    private let policy: PhotoIdentifiersFilterPolicyProtocol
    private let resultSubject = PassthroughSubject<[PhotoIdentifier], Never>()

    var result: AnyPublisher<[PhotoIdentifier], Never> {
        resultSubject.eraseToAnyPublisher()
    }

    init(storage: StorageManager, policy: PhotoIdentifiersFilterPolicyProtocol) {
        self.storage = storage
        self.policy = policy
    }

    func execute(with identifiers: [PhotoIdentifier]) {
        Task {
            await filter(identifiers: identifiers)
        }
    }

    private func filter(identifiers: [PhotoIdentifier]) async {
        let managedObjectContext = storage.backgroundContext
        let photos = storage.fetchPrimaryPhotos(moc: managedObjectContext)
        let metadata = photos.compactMap { $0.photoRevision.decryptMetadata().ios }
        let filteredIdentifiers = policy.filter(identifiers: identifiers, metadata: metadata)
        await finish(with: filteredIdentifiers)
    }

    @MainActor
    private func finish(with identifiers: [PhotoIdentifier]) {
        resultSubject.send(identifiers)
    }
}
