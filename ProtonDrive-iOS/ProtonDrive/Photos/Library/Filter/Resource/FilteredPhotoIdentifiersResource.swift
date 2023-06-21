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
    var result: AnyPublisher<PhotoIdentifiersFilterResult, Never> { get }
    func execute(with identifiers: [PhotoIdentifier])
}

final class DatabaseFilteredPhotoIdentifiersResource: FilteredPhotoIdentifiersResource {
    private let storage: StorageManager
    private let policy: PhotoIdentifiersFilterPolicyProtocol
    private let resultSubject = PassthroughSubject<PhotoIdentifiersFilterResult, Never>()

    var result: AnyPublisher<PhotoIdentifiersFilterResult, Never> {
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
        let photosAttributes = managedObjectContext.performAndWait { photos.compactMap { try? $0.photoRevision.decryptExtendedAttributes().iOSPhotos } }
        let formatter = ISO8601DateFormatter()

        var metadata: [PhotoMetadata.iOSMeta] = []
        for attribute in photosAttributes {
            guard let cloudIdentifier = attribute.iCloudID else {
                continue
            }
            let modifiedDate = formatter.date(attribute.modificationDate)

            metadata.append(PhotoMetadata.iOSMeta(cloudIdentifier: cloudIdentifier, creationDate: nil, modifiedDate: modifiedDate))
        }

        let result = policy.filter(identifiers: identifiers, metadata: metadata)
        await finish(with: result)
    }

    @MainActor
    private func finish(with result: PhotoIdentifiersFilterResult) {
        resultSubject.send(result)
    }
}
