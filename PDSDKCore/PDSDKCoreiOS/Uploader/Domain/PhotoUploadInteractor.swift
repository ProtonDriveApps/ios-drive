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

final class PhotoUploadInteractor: BaseUploadInteractor, FileUploadInteractorProtocol {
    private let cacheResource: FileUploaderCacheProtocol
    private let failedPhotosResource: DeletedPhotosIdentifierStoreResource
    private let managedObjectContext: NSManagedObjectContext
    private let operationPerformer: PhotosOperationPerformerProtocol
    private let photoUploadedNotifier: PhotoUploadedNotifier
    private let protectionResource: ProtectionResource
    private let skippableCache: PhotosSkippableCache
    private let thumbnailProvider: SynchronizedThumbnailProviderProtocol
    private lazy var storageSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.formattingContext = .standalone
        formatter.allowsNonnumericFormatting = true
        formatter.zeroPadsFractionDigits = false
        formatter.includesUnit = true
        formatter.isAdaptive = false
        return formatter
    }()
    let type = ProtonDriveSDK.NodeType.photo

    init(
        cacheResource: FileUploaderCacheProtocol,
        failedPhotosResource: DeletedPhotosIdentifierStoreResource,
        managedObjectContext: NSManagedObjectContext,
        operationPerformer: PhotosOperationPerformerProtocol,
        photoUploadedNotifier: PhotoUploadedNotifier,
        protectionResource: ProtectionResource,
        skippableCache: PhotosSkippableCache,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol,
        operationsStore: UploadOperationsStore
    ) {
        self.cacheResource = cacheResource
        self.failedPhotosResource = failedPhotosResource
        self.managedObjectContext = managedObjectContext
        self.operationPerformer = operationPerformer
        self.photoUploadedNotifier = photoUploadedNotifier
        self.protectionResource = protectionResource
        self.skippableCache = skippableCache
        self.thumbnailProvider = thumbnailProvider
        super.init(operationCancelPerformer: operationPerformer, operationsStore: operationsStore)
    }

    func upload(
        identifier: AnyVolumeIdentifier,
        token: UUID,
        conflictResolution: ConflictResolution,
        progress: @escaping ProgressCallback
    ) async throws -> AnyVolumeIdentifier {
        assert(conflictResolution == .undetermined, "Unsupported conflict resolution for photos")
        let cloudIdentifier = await cacheResource.getPhotoCloudIdentifier(for: identifier)

        do {
            let attributes = try await cacheResource.getPhotoUploadInput(from: identifier)
            try await cacheResource.updateState(for: identifier, to: .uploading)
            logUploadStart(attributes: attributes)
            let thumbnailLocalCache = ThumbnailsUploadLocalCache()
            let scheduleDate = Date()

            let operation = try await getOrMakeOperation(
                identifier: identifier,
                token: token,
                attributes: attributes,
                thumbnailLocalCache: thumbnailLocalCache,
                progress: progress
            )
            let uploadedNode = try await operationPerformer.startUpload(
                operation: operation,
                attributes: attributes,
                moc: managedObjectContext,
                thumbnailLocalCache: thumbnailLocalCache,
                onRetriableErrorReceived: { _ in }
            )
            await operationsStore.remove(id: token)

            try await handleSuccess(
                photo: uploadedNode as? CoreDataPhoto,
                tempIdentifier: identifier,
                attributes: attributes,
                uploadInterval: Date().timeIntervalSince(scheduleDate)
            )
            return uploadedNode.identifier.any()
        } catch {
            let mappedError = await handleAndMap(error: error, token: token)
            switch mappedError {
            case .cancelled, .paused:
                // no-op
                break
            case let .error(error):
                await handleGeneric(error: error, cloudIdentifier: cloudIdentifier, identifier: identifier)
            }
            throw mappedError
        }
    }

    /// Returns paused operation when found, or creates new.
    private func getOrMakeOperation(
        identifier: AnyVolumeIdentifier,
        token: UUID,
        attributes: PhotoAttributes,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol,
        progress: @escaping ProgressCallback
    ) async throws -> ProtonDriveSDK.UploadOperation {
        Log.debug("Starting to get or make operation: \(token)", domain: .sdk)
        if let item = await operationsStore.get(for: token) {
            Log.debug("Returning paused operation for \(token)", domain: .sdk)
            return item.uploadOperation
        } else {
            let operation = try await operationPerformer.uploadOperation(
                attributes: attributes,
                thumbnailProvider: thumbnailProvider,
                thumbnailLocalCache: thumbnailLocalCache,
                progressCallback: progress
            )
            let item = UploadOperationsStore.Operation(uploadOperation: operation, identifier: identifier)
            await operationsStore.store(id: token, operation: item)
            Log.debug("Created new operation for \(token)", domain: .sdk)
            return operation
        }
    }

    private func logUploadStart(attributes: PhotoAttributes) {
        var messages: [String] = [
            "Uploading photo",
            "identifier: \(attributes.cloudIdentifier)",
            "uploadID: \(attributes.uploadID)",
            "mimeType: \(attributes.mediaType)",
            "size: \(storageSizeFormatter.string(fromByteCount: attributes.fileSize))",
            "photo captureDate: \(attributes.captureTime)"
        ]

        if attributes.mainPhotoUid == nil {
            messages.append("Main photo, has \(attributes.childrenCount) children")
        } else {
            messages.append("Child photo")
        }
        Log.debug("\(messages.joined(separator: ", "))", domain: .sdk)
    }

    private func handleGeneric(error: Error, cloudIdentifier: String?, identifier: AnyVolumeIdentifier) async {
        var context = LogContext(identifier.id, forKey: "uploadID")
        if let attributes = try? await cacheResource.getPhotoUploadInput(from: identifier) {
            context["cloudIdentifier"] = attributes.cloudIdentifier
            context["isLocked"] = protectionResource.isLocked().description
            context["mainPhotoID"] = attributes.mainPhotoUid?.any.debugDesc ?? "nil"
            context["volumeID"] = identifier.volumeID
            context["maskedFilename"] = attributes.name.maskFilename()
        }
        if let sdkError = error as? ProtonDriveSDKError,
           let additionalErrorData = sdkError.additionalErrorData,
           let data = additionalErrorData as? ContentSizeMismatchErrorData {
            let sizeDelta = data.uploadedSize - data.expectedSize
            context["sizeDelta"] = sizeDelta.formatted()
        }
        Log.error("Failed to upload photo: \(error.localizedDescription)", error: error, domain: .sdk, context: context)
        
        // TODO(SDK): use correct error
        failedPhotosResource.increment(cloudIdentifier: cloudIdentifier, error: .accessFileFailed)
        await cacheResource.deleteTemp(identifier: identifier)
    }

    private func handleSuccess(
        photo: CoreDataPhoto?,
        tempIdentifier: AnyVolumeIdentifier,
        attributes: PhotoAttributes,
        uploadInterval: TimeInterval
    ) async throws {
        guard let photo else {
            Log.error("Should be a CoreDataPhoto", error: nil, domain: .sdk)
            throw SDKUploadErrors.unexpectedObjectType
        }

        let identifier = PhotoAssetMetadata.iOSPhotos(
            identifier: attributes.cloudIdentifier,
            modificationTime: attributes.modificationDate
        )
        let size = storageSizeFormatter.string(fromByteCount: attributes.fileSize)
        Log.debug("Upload photo \(tempIdentifier) success within \(uploadInterval) seconds, size: \(size)", domain: .sdk)
        skippableCache.markAsSkippable(identifier, skippableFiles: 1)
        photoUploadedNotifier.uploadCompleted(photo: photo)
    }
}
