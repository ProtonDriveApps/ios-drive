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

protocol AlbumDirectChildrenFilterPolicyProtocol {
    func filter(photoIdentifiers: [AnyVolumeIdentifier]) async throws -> [AnyVolumeIdentifier]
}

final class AlbumDirectChildrenFilterPolicy: AlbumDirectChildrenFilterPolicyProtocol {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // A quick method to verify if the local photos are direct children within an album.
    // This is not entirely reliable, as the photo limit is 10,000, and not all photos may be present locally.
    // There is a fallback mechanism in place if the backend detects that certain items are direct children of the album.
    func filter(photoIdentifiers: [AnyVolumeIdentifier]) async throws -> [AnyVolumeIdentifier] {
        return await context.perform {
            var childIDs: [AnyVolumeIdentifier] = []
            for id in photoIdentifiers {
                guard let photo = CoreDataPhoto.fetch(identifier: id, in: self.context) else {
                    childIDs.append(id)
                    continue
                }
                if !photo.hasPhotoStreamListing() {
                    // If the photo doesn't have listing in the photo stream, the photo is a child of the album
                    childIDs.append(id)
                }
            }
            return childIDs
        }
    }
}
