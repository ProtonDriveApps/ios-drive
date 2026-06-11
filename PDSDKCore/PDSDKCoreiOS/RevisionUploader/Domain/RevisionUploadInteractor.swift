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
import PDSDKCore
import ProtonDriveSDK

public protocol RevisionUploadInteractorProtocol {
    func upload(
        identifier: AnyVolumeIdentifier,
        fileUrl: URL,
        cancellationToken: UUID
    ) async throws -> AnyVolumeIdentifier
    func cancel(cancellationToken: UUID) async throws
}

final class RevisionUploadInteractor: RevisionUploadInteractorProtocol {
    private let operationPerformer: FileOperationPerformer
    private let managedObjectContext: NSManagedObjectContext
    private let thumbnailProvider: SynchronizedThumbnailProviderProtocol

    init(
        operationPerformer: FileOperationPerformer,
        managedObjectContext: NSManagedObjectContext,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol
    ) {
        self.operationPerformer = operationPerformer
        self.managedObjectContext = managedObjectContext
        self.thumbnailProvider = thumbnailProvider
    }

    func upload(identifier: AnyVolumeIdentifier, fileUrl: URL, cancellationToken: UUID) async throws -> AnyVolumeIdentifier {
        let (revisionId, shareId, oldRevisionUrls) = try await managedObjectContext.perform { [managedObjectContext] in
            let file: File = try File.fetchOrThrow(identifier: identifier, in: managedObjectContext)
            let revisionId = try file.activeRevision?.id ?! "Missing revision"
            let revisionUrls = file.activeRevision?.getFileSystemUrls() ?? []
            return (revisionId, file.shareID, revisionUrls)
        }
        let currentActiveRevisionUid = SDKRevisionUid(volumeID: identifier.volumeID, nodeID: identifier.id, revisionID: revisionId)

        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let creationDate = attributes[.creationDate] as? Date ?? Date.now
        let modificationDate = attributes[.modificationDate] as? Date ?? Date.now
        let fileAttributes = FileAttributes(fileSize: fileSize, creationDate: creationDate, modificationDate: modificationDate)
        let decodedFileUrl = URL(string: fileUrl.path(percentEncoded: false))!

        // Upload new revision
        let node = try await operationPerformer.uploadNewRevision(
            currentActiveRevisionUid: currentActiveRevisionUid,
            url: decodedFileUrl,
            fileAttributes: fileAttributes,
            shareID: shareId,
            thumbnailProvider: thumbnailProvider,
            cancellationToken: cancellationToken,
            progressCallback: { _ in },
            onRetriableErrorReceived: { _ in },
            moc: managedObjectContext
        )

        // Clean up old revision from file system
        oldRevisionUrls.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
        return node.identifier.any()
    }

    func cancel(cancellationToken: UUID) async throws {
        try await operationPerformer.cancelUpload(cancellationToken: cancellationToken)
    }
}
