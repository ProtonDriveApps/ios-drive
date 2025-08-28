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

import CoreData
import PDCore

public protocol PhotoReaderProtocol {
    func getDecryptedProperties(
        from photoID: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) async throws -> [PhotoProperty]
    func getDecryptedProperties(
        from photoID: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) throws -> [PhotoProperty]
}

public struct PhotoReader: PhotoReaderProtocol {

    public init() {}

    /// Switch to context thread to read
    public func getDecryptedProperties(
        from photoID: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) async throws -> [PhotoProperty] {
        try await context.perform {
            try getDecryptedProperties(from: photoID, in: context)
        }
    }

    /// Will not switch to context thread, use when you already in a context thread
    public func getDecryptedProperties(
        from photoID: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) throws -> [PhotoProperty] {
        guard let photo = CoreDataPhoto.fetch(identifier: photoID, in: context) else {
            throw Errors.PhotoDoesNotExist
        }
        let mainProperty = try getDecryptedProperties(photo: photo)
        var childrenProperties: [PhotoProperty] = []
        for child in photo.children {
            let property = try getDecryptedProperties(photo: child)
            childrenProperties.append(property)
        }

        return [mainProperty] + childrenProperties
    }

    private func getDecryptedProperties(photo: CoreDataPhoto) throws -> PhotoProperty {
        guard let parent = photo.parentNode else { throw Errors.listingDoesNotExist }
        let contentHashDigest = try photo.photoRevision.getContentDigest()
        return .init(
            contentHashDigest: contentHashDigest,
            decryptedName: try photo.decryptName(),
            decryptedParentPassphrase: try parent.decryptPassphrase(),
            parentKey: parent.nodeKey,
            passphrase: photo.nodePassphrase,
            photoID: AnyVolumeIdentifier(id: photo.id, volumeID: photo.volumeID)
        )
    }
}

extension PhotoReader {
    enum Errors: Error {
        case PhotoDoesNotExist
        case listingDoesNotExist
    }
}

public struct PhotoProperty {
    public let contentHashDigest: FileContentDigest
    public let decryptedName: String
    public let decryptedParentPassphrase: String
    public let parentKey: String
    public let passphrase: String
    public let photoID: AnyVolumeIdentifier
}
