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
import PDCore

protocol PhotosFilterByIdResource {
    func execute(with identifiers: PhotoIdentifiers) async -> PhotoIdentifiersFilterResult
}

final class DatabasePhotosFilterByIdResource: PhotosFilterByIdResource {
    private let storage: StorageManager
    private let policy: PhotoIdentifiersFilterPolicyProtocol
    private let managedObjectContext: NSManagedObjectContext
    private static let formatter = ISO8601DateFormatter()

    init(storage: StorageManager, policy: PhotoIdentifiersFilterPolicyProtocol) {
        self.storage = storage
        self.policy = policy
        managedObjectContext = storage.newBackgroundContext()
    }

    func execute(with identifiers: PhotoIdentifiers) async -> PhotoIdentifiersFilterResult {
        // TODO: Only checking duplicates against unfinished uploads.
        // Otherwise they would be added to the queue, since BE doesn't know them yet (duplicity).
        // Need better strategy in the future.
        let photos = storage.fetchMyPrimaryUploadingPhotos(moc: managedObjectContext)
        let photosAttributes = await managedObjectContext.perform { [weak self] in
            photos.compactMap { self?.getPhotosAttributes(from: $0) }
        }

        var metadata: [PhotoMetadata.iOSMeta] = []
        for attribute in photosAttributes {
            guard let cloudIdentifier = attribute.iCloudID else {
                continue
            }
            let modifiedDate = DatabasePhotosFilterByIdResource.formatter.date(attribute.modificationTime)
            metadata.append(PhotoMetadata.iOSMeta(cloudIdentifier: cloudIdentifier, modifiedDate: modifiedDate))
        }

        return policy.filter(identifiers: identifiers, metadata: metadata)
    }

    private func getPhotosAttributes(from photo: Photo) -> ExtendedAttributes.iOSPhotos? {
        getPhotosAttributesFromTemporaryAttributes(photo) ?? getPhotosAttributesFromRevision(photo)
    }

    private func getPhotosAttributesFromRevision(_ photo: Photo) -> ExtendedAttributes.iOSPhotos? {
        try? photo.photoRevision.unsafeDecryptedExtendedAttributes().iOSPhotos
    }

    private func getPhotosAttributesFromTemporaryAttributes(_ photo: Photo) -> ExtendedAttributes.iOSPhotos? {
        TemporalMetadata(base64String: photo.tempBase64Metadata)?.iOSPhotos
    }
}
