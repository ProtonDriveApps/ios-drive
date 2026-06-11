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

import CoreData
import PDCore
import ProtonDriveSDK

protocol PhotoDownloaderCacheProtocol {
    func getDownloadInput(for identifier: AnyVolumeIdentifier, options: SDKFileDownloadOptions) async throws -> PhotoDownloadInput
    func finalizeDownload(for input: PhotoDownloadInput) throws
    func cleanUp(for input: PhotoDownloadInput)
}

struct PhotoDownloadInput {
    let temporaryUrl: URL
    let destinationUrl: URL
    let clearSize: Int
    let shareID: String
}

final class PhotoDownloaderCache: PhotoDownloaderCacheProtocol {
    private let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    func getDownloadInput(for identifier: AnyVolumeIdentifier, options: SDKFileDownloadOptions) async throws -> PhotoDownloadInput {
        let managedObjectContext = self.managedObjectContext
        return try await managedObjectContext.perform {
            let photo: CoreDataPhoto = try CoreDataPhoto.fetchOrThrow(
                identifier: identifier,
                allowSubclasses: true,
                in: managedObjectContext
            )
            let identifier = photo.volumeBasedIdentifierWithinManagedObjectContext
            let destinationUrl = self.getDestinationUrl(identifier: identifier, options: options)

            // Intentionally not using name for temporary file since SDK deescapes it and then we can't access it easily.
            // Uniqueness is guarded by using `identifier` as folder name
            let temporaryUrl = PDFileManager.fileURL(
                for: identifier,
                prefix: "sdk_downloads",
                storageType: .temporary,
                shouldCreate: true
            )
            return PhotoDownloadInput(
                temporaryUrl: temporaryUrl,
                destinationUrl: destinationUrl,
                clearSize: photo.size,
                shareID: photo.shareID
            )
        }
    }

    private func getDestinationUrl(identifier: NodeIdentifier, options: SDKFileDownloadOptions) -> URL {
        if options.contains(.saveAsOfflineAvailable) {
            return DecryptedFileManager.permanentClearURL(identifier: identifier, shouldCreate: true)
        } else {
            return DecryptedFileManager.temporaryClearURL(identifier: identifier, shouldCreate: true)
        }
    }

    func finalizeDownload(for input: PhotoDownloadInput) throws {
        _ = try FileManager.default.replaceItemAt(input.destinationUrl, withItemAt: input.temporaryUrl)
        let tempFolderPath = input.temporaryUrl.deletingLastPathComponent()
        try FileManager.default.removeItem(at: tempFolderPath)
    }

    func cleanUp(for input: PhotoDownloadInput) {
        try? FileManager.default.removeItem(at: input.temporaryUrl)
    }
}
