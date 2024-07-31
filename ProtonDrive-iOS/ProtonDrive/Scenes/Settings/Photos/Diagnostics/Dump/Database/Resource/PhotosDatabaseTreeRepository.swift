// Copyright (c) 2024 Proton AG
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
import Photos
import PDCore

final class PhotosDatabaseTreeRepository: TreeRepository {
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(storageManager: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.storageManager = storageManager
        self.managedObjectContext = managedObjectContext
    }

    func get() async throws -> Tree {
        Log.debug("Fetching all photos from DB", domain: .diagnostics)
        let items: [Tree.Node] = try await managedObjectContext.perform {
            let photos = self.storageManager.fetchPrimaryPhotos(moc: self.managedObjectContext)

            // Group photos by iCloud identifier
            var dictionary = [String: [Photo]]()
            try photos.forEach { photo in
                let identifier = try photo.iOSPhotos()?.identifier ?! "Missing identifier"
                dictionary[identifier] = (dictionary[identifier] ?? []) + [photo]
            }

            // Each identifier will represent a single node with photos as children
            return try dictionary.map { identifier, photos in
                try self.makeListNode(identifier: identifier, photos: photos)
            }
        }
        return Tree(root: Tree.Node(nodeTitle: "root", descendants: items))
    }

    private func makeListNode(identifier: String, photos: [Photo]) throws -> Tree.Node {
        return Tree.Node(
            nodeTitle: identifier,
            descendants: try photos.map(makePhotoNode)
        )
    }

    private func makePhotoNode(from photo: Photo) throws -> Tree.Node {
        let title = try photo.decryptName()
        let descendants = try photo.children.map(makePhotoNode)
        return Tree.Node(nodeTitle: title, descendants: descendants)
    }
}
