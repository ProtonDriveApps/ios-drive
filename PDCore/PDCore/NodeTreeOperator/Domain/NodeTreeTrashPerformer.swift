// Copyright (c) 2026 Proton AG
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

import Foundation
import CoreData

/// Update trashed node state locally
/// Set state to `deleted` and update offline available state
public struct NodeTreeTrashPerformer: Sendable {

    public init() {}

    public func performAndSave(
        to nodeIDs: [AnyVolumeIdentifier],
        in moc: NSManagedObjectContext
    ) async throws -> [CoreDataFile] {
        return try await moc.perform { [moc] in
            let nodes = Node.fetch(identifiers: Set(nodeIDs), allowSubclasses: true, in: moc)
            let affectedFiles = self.perform(to: nodes, in: moc)
            try moc.saveIfNeeded()
            return affectedFiles
        }
    }

    public func perform(to nodes: [Node], in moc: NSManagedObjectContext) -> [CoreDataFile] {
        let (files, folders, photos) = self.cast(nodes: nodes)
        Log.debug("Handle trash locally for \(files.count) files, \(folders.count) folders and \(photos.count) photos", domain: .nodeOperation)
        var affectedFiles: [CoreDataFile] = []
        affectedFiles.append(contentsOf: trash(files: files, isRootNode: true))
        affectedFiles.append(contentsOf: trash(photos: photos, moc: moc))
        affectedFiles.append(contentsOf: trash(folders: folders, isRootNode: true))
        return affectedFiles
    }

    private func trash(files: [CoreDataFile], isRootNode: Bool) -> [CoreDataFile] {
        for file in files {
            if isRootNode {
                file.state = .deleted
            }
            file.isMarkedOfflineAvailable = false
            file.isInheritingOfflineAvailable = false
        }
        return files
    }

    private func trash(photos: [CoreDataPhoto], moc: NSManagedObjectContext) -> [CoreDataPhoto] {
        var affectedPhotos: [CoreDataPhoto] = []
        for photo in photos {
            photo.state = .deleted
            photo.isMarkedOfflineAvailable = false
            photo.isInheritingOfflineAvailable = false

            // Listings need to be deleted immediately to propagate the change to UI.
            photo.photoListings.forEach { moc.delete($0) }
            affectedPhotos.append(contentsOf: [photo] + trash(photos: Array(photo.children), moc: moc))
        }
        return affectedPhotos
    }

    private func trash(folders: [CoreDataFolder], isRootNode: Bool) -> [CoreDataFile] {
        var files: [CoreDataFile] = []
        for folder in folders {
            if isRootNode {
                folder.state = .deleted
            }
            folder.isMarkedOfflineAvailable = false
            folder.isInheritingOfflineAvailable = false

            let (childFiles, childFolders) = children(from: folder)
            files.append(contentsOf: trash(files: childFiles, isRootNode: false))
            files.append(contentsOf: trash(folders: childFolders, isRootNode: false))
        }
        return files
    }

    private func cast(nodes: [Node]) -> ([CoreDataFile], [CoreDataFolder], [CoreDataPhoto]) {
        let files = nodes.compactMap { $0 as? CoreDataFile }
        let folders = nodes.compactMap { $0 as? CoreDataFolder }
        let photos = nodes.compactMap { $0 as? CoreDataPhoto }
        return (files, folders, photos)
    }

    private func children(from parent: CoreDataFolder) -> ([CoreDataFile], [CoreDataFolder]) {
        let files = parent.children.compactMap { $0 as? CoreDataFile }
        let folders = parent.children.compactMap { $0 as? CoreDataFolder }
        return (files, folders)
    }
}
