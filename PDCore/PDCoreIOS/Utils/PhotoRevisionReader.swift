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

public protocol PhotoRevisionReaderProtocol {
    func read(
        photoIdentifier: AnyVolumeIdentifier,
        in managedContext: NSManagedObjectContext
    ) async throws -> RevisionProperty?

    func read(
        photoIdentifier: AnyVolumeIdentifier,
        in managedContext: NSManagedObjectContext
    ) throws -> RevisionProperty?
}

public struct PhotoRevisionReader: PhotoRevisionReaderProtocol {
    public init() {}

    public func read(
        photoIdentifier: AnyVolumeIdentifier,
        in managedContext: NSManagedObjectContext
    ) async throws -> RevisionProperty? {
        try await managedContext.perform {
            try read(photoIdentifier: photoIdentifier, in: managedContext)
        }
    }

    public func read(
        photoIdentifier: AnyVolumeIdentifier,
        in managedContext: NSManagedObjectContext
    ) throws -> RevisionProperty? {
        guard let photo = CoreDataPhoto.fetch(identifier: photoIdentifier, in: managedContext) else { return nil }
        let attributes = try photo.photoRevision.decryptedExtendedAttributes()
        return RevisionProperty(
            decryptedExtendedAttributes: attributes,
            signatureEmail: try photo.signatureEmail ?! "Signature email is nil",
            nodeKey: photo.nodeKey,
            revisionID: photo.photoRevision.id
        )
    }
}

public struct RevisionProperty {
    public let decryptedExtendedAttributes: ExtendedAttributes
    public let signatureEmail: String
    /// Photo node key
    public let nodeKey: String
    public let revisionID: String

    public init(
        decryptedExtendedAttributes: ExtendedAttributes,
        signatureEmail: String,
        nodeKey: String,
        revisionID: String
    ) {
        self.decryptedExtendedAttributes = decryptedExtendedAttributes
        self.signatureEmail = signatureEmail
        self.nodeKey = nodeKey
        self.revisionID = revisionID
    }
}
