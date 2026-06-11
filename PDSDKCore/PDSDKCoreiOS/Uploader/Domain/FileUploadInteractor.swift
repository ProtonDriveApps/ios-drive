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
import PDSDKCore
import ProtonDriveSDK

protocol FileUploadInteractorProtocol {
    /// Returns identifier or throws `FileUploadInteractorError`
    func upload(
        identifier: AnyVolumeIdentifier,
        token: UUID,
        conflictResolution: ConflictResolution,
        progress: @escaping ProgressCallback
    ) async throws -> AnyVolumeIdentifier
    func cancel(token: UUID) async
    func pause(token: UUID) async throws
    func getPausedIdentifiers() async -> Set<AnyVolumeIdentifier>

    var type: ProtonDriveSDK.NodeType { get }
}

enum FileUploadInteractorError: Error {
    case cancelled
    case paused
    case error(Error)
}

/// Interactor that handles uploading a common file to My Files, Computer and shared folders
final class FileUploadInteractor: BaseUploadInteractor, FileUploadInteractorProtocol {
    private let cacheResource: FileUploaderCacheProtocol
    private let managedObjectContext: NSManagedObjectContext
    private let operationPerformer: FileOperationPerformer
    private let protectionResource: ProtectionResource
    private let thumbnailProvider: SynchronizedThumbnailProviderProtocol
    let type = ProtonDriveSDK.NodeType.file

    init(
        cacheResource: FileUploaderCacheProtocol,
        managedObjectContext: NSManagedObjectContext,
        operationPerformer: FileOperationPerformer,
        protectionResource: ProtectionResource,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol,
        operationsStore: UploadOperationsStore
    ) {
        self.cacheResource = cacheResource
        self.managedObjectContext = managedObjectContext
        self.operationPerformer = operationPerformer
        self.protectionResource = protectionResource
        self.thumbnailProvider = thumbnailProvider
        super.init(operationCancelPerformer: operationPerformer, operationsStore: operationsStore)
    }

    func upload(
        identifier: AnyVolumeIdentifier,
        token: UUID,
        conflictResolution: ConflictResolution,
        progress: @escaping ProgressCallback
    ) async throws -> AnyVolumeIdentifier {
        var maskedFilename: String?
        do {
            // To enable resumability, we need to make sure `getUploadInput` returns same data for a given file
            let input = try await cacheResource.getUploadInput(from: identifier)
            maskedFilename = input.filename.maskFilename()
            try await cacheResource.updateState(for: input.identifier, to: .uploading)
            log(input)
            let createdFile: Node
            if let item = await operationsStore.get(for: token) {
                Log.debug("Resuming paused operation: \(token.uuidString)", domain: .sdk)
                createdFile = try await operationPerformer.startUpload(
                    operation: item.uploadOperation,
                    parentFolderUid: input.parentIdentifier,
                    url: input.resourceURL,
                    fileAttributes: input.fileAttributes,
                    cancellationToken: input.uploadID,
                    moc: managedObjectContext,
                    thumbnailLocalCache: ThumbnailsUploadLocalCache(),
                    onRetriableErrorReceived: { _ in }
                )
            } else {
                Log.debug("Uploading from scratch: \(token.uuidString)", domain: .sdk)
                createdFile = try await operationPerformer.uploadFile(
                    parentFolderUid: input.parentIdentifier,
                    name: input.filename,
                    url: input.resourceURL,
                    fileAttributes: input.fileAttributes,
                    shareID: input.shareID,
                    mediaType: input.mimeType,
                    cancellationToken: input.uploadID,
                    progressCallback: progress,
                    onRetriableErrorReceived: { _ in },
                    moc: managedObjectContext,
                    thumbnailProvider: thumbnailProvider,
                    thumbnailLocalCache: ThumbnailsUploadLocalCache(),
                    conflictResolution: conflictResolution,
                    onUploadOperationChange: { [weak self] uploadOperation in
                        // Can be invoked multiple times depending on name resolution logic
                        if let uploadOperation {
                            let item = UploadOperationsStore.Operation(uploadOperation: uploadOperation, identifier: identifier)
                            await self?.operationsStore.store(id: token, operation: item)
                        } else {
                            await self?.operationsStore.remove(id: token)
                        }
                    }
                )
            }
            await operationsStore.remove(id: token)
            return createdFile.identifier.any()
        } catch {
            let mappedError = await handleAndMap(error: error, token: token)
            logErrorIfNeeded(error: mappedError, token: token, identifier: identifier, maskedFilename: maskedFilename)
            throw mappedError
        }
    }
    
    private func logErrorIfNeeded(error: FileUploadInteractorError, token: UUID, identifier: AnyVolumeIdentifier, maskedFilename: String?) {
        let isLocked = protectionResource.isLocked()
        var context = LogContext(token.uuidString, forKey: "uploadID")
        context["volumeID"] = identifier.volumeID
        if let maskedFilename {
            context["filename"] = maskedFilename
        }
        guard !isLocked else {
            Log.error("Failed to upload file, isLocked", error: error, domain: .sdk, context: context)
            return
        }
        switch error {
        case .cancelled:
            Log.debug("Cancelled upload \(token.uuidString)", domain: .sdk)
        case .paused:
            Log.debug("Paused upload \(token.uuidString)", domain: .sdk)
        case .error(let error):
            Log.error("Failed to upload file, \(error.localizedDescription)", error: error, domain: .sdk, context: context)
        }
    }

    private func log(_ input: UploadFileInput) {
        let message = "Uploading \(input.uploadID), MimeType: \(input.mimeType), Size: \(input.fileAttributes.fileSize)"
        Log.debug(message, domain: .sdk)
    }
}
