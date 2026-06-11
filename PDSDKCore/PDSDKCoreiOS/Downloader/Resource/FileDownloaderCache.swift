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
import ProtonDriveSDK

protocol FileDownloaderCacheProtocol {
    func getDownloadInput(for identifier: AnyVolumeIdentifier, options: SDKFileDownloadOptions) async throws -> FileDownloadInput
    func finalizeDownload(for input: FileDownloadInput) throws
    func cleanUp(for input: FileDownloadInput)
}

struct FileDownloadInput {
    let id: AnyVolumeIdentifier
    let mimeType: String // For log
    let name: String
    let shareId: String
    let revisionUid: SDKRevisionUid
    let temporaryUrl: URL
    let temporaryDecodedUrl: URL
    let destinationUrl: URL
    let clearSize: Int
}

final class FileDownloaderCache: FileDownloaderCacheProtocol, Sendable {
    private let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func getDownloadInput(for identifier: AnyVolumeIdentifier, options: SDKFileDownloadOptions) async throws -> FileDownloadInput {
        let managedObjectContext = self.managedObjectContext
        return try await managedObjectContext.perform {
            let file: File = try File.fetchOrThrow(identifier: identifier, allowSubclasses: true, in: managedObjectContext)
            return try self.getInputInContext(for: file, options: options)
        }
    }

    private func getInputInContext(for file: File, options: SDKFileDownloadOptions) throws -> FileDownloadInput {
        let revision = try file.activeRevision ?! "Missing revision"
        let name = file.decryptedName
        let revisionIdentifier = revision.identifier
        let identifier = file.identifierWithinManagedObjectContext
        let revisionUid = SDKRevisionUid(volumeID: revisionIdentifier.volumeID, nodeID: revisionIdentifier.fileID, revisionID: revisionIdentifier.revisionID)
        let destinationUrl = getDestinationUrl(identifier: identifier, options: options)
        // Intentionally not using name for temporary file since SDK deescapes it and then we can't access it easily.
        // Uniqueness is guarded by using `identifier` as folder name
        let temporaryUrl = PDFileManager
            .fileURL(for: identifier, prefix: "sdk_downloads", storageType: .temporary, shouldCreate: true)
        return FileDownloadInput(
            id: identifier.any(),
            mimeType: file.mimeType,
            name: name,
            shareId: revisionIdentifier.shareID,
            revisionUid: revisionUid,
            temporaryUrl: temporaryUrl,
            temporaryDecodedUrl: URL(string: temporaryUrl.path(percentEncoded: false))!,
            destinationUrl: destinationUrl,
            clearSize: file.size
        )
    }

    private func getDestinationUrl(identifier: NodeIdentifier, options: SDKFileDownloadOptions) -> URL {
        if options.contains(.saveAsOfflineAvailable) {
            return DecryptedFileManager.permanentClearURL(identifier: identifier, shouldCreate: true)
        } else {
            return DecryptedFileManager.temporaryClearURL(identifier: identifier, shouldCreate: true)
        }
    }

    func finalizeDownload(for input: FileDownloadInput) throws {
        _ = try FileManager.default.replaceItemAt(input.destinationUrl, withItemAt: input.temporaryUrl)
        let tempFolderPath = input.temporaryUrl.deletingLastPathComponent()
        try FileManager.default.removeItem(at: tempFolderPath)
    }

    func cleanUp(for input: FileDownloadInput) {
        try? FileManager.default.removeItem(at: input.temporaryUrl)
    }
}
