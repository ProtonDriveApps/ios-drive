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

import Foundation
import CoreData
import PDCore
import UIKit

final class CoreDataFilePreviewRepository: FilePreviewRepository {
    private let context: NSManagedObjectContext
    private let file: File

    @ThreadSafe private var cleartextUrl: URL?
    private var isCancelled = false

    init(context: NSManagedObjectContext, file: File) {
        self.context = context
        self.file = file
    }
    
    func getURL() -> URL {
        if let cleartextUrl = cleartextUrl, FileManager.default.fileExists(atPath: cleartextUrl.path) {
            return cleartextUrl
        } else {
            Log.error(error: DriveError("The file was not found."), domain: .fileManager)
            return URL.blank
        }
    }
    
    func requiresDecryption() async throws -> Bool {
        let objectID = file.objectID
        let decryptedPath = try await context.perform { [context] in
            let file: CoreDataFile = try context.typedObject(with: objectID)
            guard let revision = file.activeRevision else {
                throw file.invalidState("No active revision in file")
            }
            return revision.validatedDecryptedFilePath()
        }
        if let decryptedPath {
            cleartextUrl = try decryptedPath.hardLink(filename: file.decryptedName)
            return false
        } else {
            return true
        }
    }

    func loadFile() async throws {
        Log.info("Will start decrypting the file", domain: .fileManager)
        let objectID = file.objectID
        return try await context.perform { [context] in
            do {
                let file: CoreDataFile = try context.typedObject(with: objectID)
                guard self.cleartextUrl == nil, let revision = file.activeRevision else {
                    throw file.invalidState("No active revision in file")
                }

                // The decrypted file is stored at `{UserID}/{VolumeID}/{NodeID}/clear`
                // Create a hard link that points to this location
                // so the preview view and share sheet can display the correct file name
                //
                // In Finder, you will see two files: `clear` and `{name}.{ext}`
                // The folder size will appear doubled because Finder simply sums the size of each entry
                // However, both files reference the same inode, so no data is actually duplicated
                // You can run `ls -li path_to_folder` to confirm that they point to the same inode
                // And `du -h path_to_folder` to see actual disk usage
                let realLink = try revision.decryptFile(isCancelled: &self.isCancelled)
                let hardLink = try realLink.hardLink(filename: file.decryptedName)
                self.cleartextUrl = hardLink
                if self.isCancelled {
                    self.cleartextUrl = nil
                    throw CancellationError()
                }
            } catch {
                self.cleartextUrl = nil
                throw error
            }
        }
    }

    func getFileMetadata() async -> (AnyVolumeIdentifier, MimeType) {
        await context.perform { [context] in
            let file = self.file.in(moc: context)
            let id = file.identifierWithinManagedObjectContext.any()
            let mimeType = MimeType(value: file.mimeType)
            return (id, mimeType)
        }
    }

    deinit {
        cancel()
    }
}

extension CoreDataFilePreviewRepository {
    func cancel() {
        self.isCancelled = true
    }
}
