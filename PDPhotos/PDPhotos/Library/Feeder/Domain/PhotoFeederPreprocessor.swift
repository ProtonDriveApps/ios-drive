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

import Foundation
@preconcurrency import PDCore
import Combine
import Photos
import CoreData
import PDCoreIOS

public final class PhotoFeederPreprocessor: PhotoFeederPreprocessorProtocol {
    private let dependencies: Dependencies
    private var cancellables: Set<AnyCancellable> = []
    private var currentTask: Task<(), any Error>?
    /// Can be temporarily disabled during cleanup
    @ThreadSafe private var isEnabled = true

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
        subscribeToFeed()
    }

    public func suspend() {
        currentTask?.cancel()
        currentTask = nil
    }

    deinit {
        currentTask?.cancel()
        currentTask = nil
    }

    private func subscribeToFeed() {
        dependencies.feedPublisher
            .asyncFilter { [weak self] _ in
                // If there are no paused photos, there should be no impact on performance.
                // If some photos are paused, the following steps can determine whether more can be processed.
                await self?.resume()
                let isUnderLimited = await self?.isUnderLimited() ?? false
                let isEnabled = self?.isEnabled ?? false
                let shouldFeed = isUnderLimited && isEnabled
                if !shouldFeed {
                    Log.info("Ignore feed request, isUnderLimited: \(isUnderLimited), isEnabled: \(isEnabled)", domain: .uploader)
                }
                return shouldFeed
            }
            .flatMap(maxPublishers: .max(1)) { [weak self] _ in
                self?.performPreprocess() ?? Empty().eraseToAnyPublisher()
            }
            .sink { [weak self] feedingPhotos in
                guard let self else { return }
                let processingPhotos = dependencies.uploader.getExecutableOperationsCount()
                Log.info("📸☁️✅ Photo upload scheduled willAdd: \(feedingPhotos.count) Total: \(feedingPhotos.count + processingPhotos)", domain: .uploader)
                self.upload(photos: feedingPhotos)
            }
            .store(in: &cancellables)
    }

    // (total pending count, feed photos)
    private func performPreprocess() -> AnyPublisher<[(NSManagedObjectID, AnyVolumeIdentifier)], Never> {
        Deferred { [weak self] in
            Future<[(NSManagedObjectID, AnyVolumeIdentifier)], Never> { [weak self] promise in
                self?.currentTask = Task { [weak self] in
                    guard let self, !Task.isCancelled else {
                        Log.debug("is cancelled: \(Task.isCancelled), self is nil: \(self == nil)", domain: .uploader)
                        promise(.success([]))
                        return
                    }
                    do {
                        let photos = self.fetchPendingPhotos()
                        if photos.isEmpty || checkTaskIsCancelled() {
                            promise(.success([]))
                            return
                        }
                        let groupResult = await self.groupPhotos(photos: photos)
                        if checkTaskIsCancelled() {
                            promise(.success([]))
                            return
                        }
                        let (copiedPhotos, copiedFailedPhotos) = try await self.copyPhotoIfNeeded(photoData: groupResult.dataToBeCopied)
                        if checkTaskIsCancelled() {
                            promise(.success([]))
                            return
                        }
                        let invalidPhotos = groupResult.invalidPhotos + copiedFailedPhotos
                        try await handle(invalidPhotos: invalidPhotos)
                        Log.debug("Get \(photos.count) from repository, \(groupResult.copiedPhotos.count) is ready, \(groupResult.dataToBeCopied.count) need to be copied, \(copiedPhotos.count) is copied, \(invalidPhotos.count) is invalid", domain: .uploader)

                        let feedingPhotos = groupResult.copiedPhotos + copiedPhotos
                        await cleanupIfNeeded(pendingCount: photos.count, processedCount: feedingPhotos.count + invalidPhotos.count)
                        promise(.success(feedingPhotos))
                    } catch {
                        Log.error("Process photo failed", error: error, domain: .photosProcessing)
                        promise(.success([]))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func checkTaskIsCancelled(line: Int = #line) -> Bool {
        if Task.isCancelled {
            Log.debug("Task is cancelled", domain: .uploader, line: line)
            return true
        }
        return false
    }
}

// MARK: - Group photos
extension PhotoFeederPreprocessor {
    private func groupPhotos(photos: [CoreDataPhoto]) async -> GroupResult {
        return await dependencies.storageManager.backgroundContextPool.performInContext { [weak self] context in
            let result = GroupResult()
            guard let self else { return result }

            for photo in photos {
                let photo = photo.in(moc: context)
                // Not sure why this happens
                // Might be a race condition, the photo was uploaded a few seconds ago
                // but the query runs before the state is updated
                if photo.state == .active {
                    result.skippedPhotos.append((photo.objectID, photo.genericIdentifier))
                    continue
                }
                guard let uploadID = self.uploadID(from: photo) else {
                    result.append(invalidPhoto: photo)
                    continue
                }

                if self.isPhotoToBeCopied(revision: photo.photoRevision) {
                    if photo.isUploading {
                        // Ignore uploading photos
                        // This should only happen if the OS cleaned up our sandbox while the app is in BG
                        Log.warning("Photo \(uploadID) is uploading but doesn't have sandbox copy", domain: .uploader)
                        result.skippedPhotos.append((photo.objectID, photo.genericIdentifier))
                        continue
                    }
                    guard let (identifier, photoData) = self.getDataToCopy(photo: photo, context: context) else {
                        result.append(invalidPhoto: photo)
                        continue
                    }
                    Log.debug("Photo \(uploadID) needs copying to sandbox", domain: .uploader)
                    result.appendCopiedPhotoData(id: identifier, data: photoData)

                } else {
                    // The photo has been copied to the temporary folder and is ready for upload.
                    // Uploading begins with encrypting the file in blocks.
                    // Once encryption is complete, the resource URL will be set to nil.
                    Log.debug("Photo \(uploadID) is copied in sandbox", domain: .uploader)
                    result.copiedPhotos.append((photo.objectID, photo.genericIdentifier))
                }
            }
            return result
        }
    }

    private func isPhotoToBeCopied(revision: CoreDataPhotoRevision) -> Bool {
        if let resourceURL = revision.normalizedUploadableResourceURL, FileManager.default.fileExists(atPath: resourceURL.path()) {
            // We already have file in temporary storage
            return false
        } else if !revision.blocks.isEmpty {
            // We already have blocks in storage. This is used by legacy uploader
            return false
        } else {
            // Otherwise we need to copy file to temporary storage to allow upload
            return true
        }
    }

    private func getDataToCopy(photo: CoreDataPhoto, context: NSManagedObjectContext) -> (Identifier, PhotoData)? {
        guard
            let uploadID = photo.uploadID,
            let metadata = TemporalMetadata(base64String: photo.tempBase64Metadata),
            let iCloudID = metadata.iOSPhotos.iCloudID,
            let resourceType = photo.photoRevision.uploadResourceTypeValue
        else {
            // These variables shouldn't be nil
            Log.warning("Can't get expected value from \(photo.uploadID?.uuidString ?? "unknown uploadID")", domain: .photosProcessing)
            assertionFailure()
            return nil
        }
        let data = PhotoData(
            identifier: photo.genericIdentifier,
            resourceType: resourceType,
            decryptedName: photo.decryptedName,
            photoObjectID: photo.objectID,
            uploadID: uploadID.uuidString
        )
        let id = Identifier(
            localIdentifier: photo.localIdentifier,
            cloudIdentifier: iCloudID
        )
        return (id, data)
    }

    private func uploadID(from photo: CoreDataPhoto) -> String? {
        photo.uploadID?.uuidString
    }
}

// MARK: - Copy photo data
extension PhotoFeederPreprocessor {
    private func copyPhotoIfNeeded(photoData: [Identifier: [PhotoData]]) async throws -> ([(NSManagedObjectID, AnyVolumeIdentifier)], [InvalidPhoto]) {
        var copiedPhotos: [(NSManagedObjectID, AnyVolumeIdentifier)] = []
        var invalidPhotos: [InvalidPhoto] = []
        for (identifier, data) in photoData {
            if dependencies.folderSizeResource.isSizeOverLimit() {
                Log.warning("Folder size over limit, stopping photo copy", domain: .photosProcessing)
                break
            }
            guard let localID = identifier.localIdentifier ?? dependencies.photoIdentifierInquirer.localIdentifier(forCloudIdentifier: identifier.cloudIdentifier) else {
                Log.warning("Local identifier is nil", domain: .uploader)
                invalidPhotos.append(
                    InvalidPhoto(
                        cloudIdentifier: identifier.cloudIdentifier,
                        error: .loadResourceFailed,
                        objectIDs: data.map(\.photoObjectID)
                    )
                )
                continue
            }

            do {
                let photos = try await copyPhoto(
                    localIdentifier: localID,
                    cloudIdentifier: identifier.cloudIdentifier,
                    data: data
                )
                if checkTaskIsCancelled() { return ([], []) }
                Log.debug("Copy photo \(data.map(\.uploadID)) succeed", domain: .uploader)
                copiedPhotos.append(contentsOf: photos)
            } catch {
                Log.error("Copy photo \(data.map(\.uploadID)) fails", error: error, domain: .uploader)
                let userError = (error as? PhotosFailureUserError) ?? .unknown
                invalidPhotos.append(
                    InvalidPhoto(
                        cloudIdentifier: identifier.cloudIdentifier,
                        error: userError,
                        objectIDs: data.map(\.photoObjectID)
                    )
                )
            }
        }
        return (copiedPhotos, invalidPhotos)
    }

    private func copyPhoto(
        localIdentifier: String,
        cloudIdentifier: String,
        data: [PhotoData]
    ) async throws -> [(NSManagedObjectID, AnyVolumeIdentifier)] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)

        guard let asset = fetchResult.firstObject else {
            Log.warning("Can't fetch asset", domain: .uploader)
            throw PhotosFailureUserError.accessFileFailed
        }
        let resources = fetchResources(from: asset)
        var copiedPhotos: [(NSManagedObjectID, AnyVolumeIdentifier)] = []
        for info in data {
            guard
                let resource = resource(resources, for: info)
            else {
                Log.error("Can't find resource", error: nil, domain: .uploader)
                throw PhotosFailureUserError.accessFileFailed
            }
            if checkTaskIsCancelled() { return [] }
            let url = try await copy(resource: resource, filename: info.decryptedName, uploadID: info.identifier.id)
            let result = try await update(url: url, to: info.identifier)
            copiedPhotos.append(result)
        }
        return copiedPhotos
    }

    private func fetchResources(from asset: PHAsset) -> [PHAssetResource] {
        let primaryResources = PHAssetResource.assetResources(for: asset)
        var secondaryResources: [PHAssetResource] = []

        if let burstIdentifier = asset.burstIdentifier {
            let fetchOptions = PHFetchOptions.defaultPhotosOptions()
            fetchOptions.includeAllBurstAssets = true
            let fetchResult = PHAsset.fetchAssets(withBurstIdentifier: burstIdentifier, options: fetchOptions)
            var secondaryAssets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                secondaryAssets.append(asset)
            }
            for secondaryAsset in secondaryAssets {
                secondaryResources.append(contentsOf: PHAssetResource.assetResources(for: secondaryAsset))
            }
        }
        return primaryResources + secondaryResources
    }

    private func resource(_ resources: [PHAssetResource], for info: PhotoFeederPreprocessor.PhotoData) -> PHAssetResource? {
        let candidates = resources.filter { $0.type.rawValue == info.resourceType }
        var result: PHAssetResource?
        if candidates.count == 1 {
            // For plain photo, live photo, video...etc
            result = candidates.first
        } else {
            // For burst photo
            result = candidates.filter { $0.originalFilename == info.decryptedName }.first
            if result == nil {
                // For modified burst photo and other unknown expectation
                let message = [
                    "Seeking resource for \(info.decryptedName), type: \(info.resourceType)",
                    "Fallback result \(candidates.first?.originalFilename ?? "unknown"), type: \(candidates.first?.type.rawValue ?? -1)"
                ].joined(separator: "\n")
                Log.debug(message, domain: .uploader)
                result = candidates.first
            }
        }
        return result
    }

    private func copy(resource: PHAssetResource, filename: String, uploadID: String) async throws -> URL {
        do {
            if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                let cachedSize = dependencies.folderSizeResource.usedSize()
                Log.debug("Copy \(uploadID), size: \(fileSize), cachedFolder size: \(cachedSize)", domain: .photosProcessing)
            }
            // To avoid implicit path validations in `PHAssetResourceManager` (ending with `PHPhotosErrorDomain Code=-1`)
            // We use just the extension (required by the thumbnail generation service), but otherwise replace
            // the name by uuid.
            let uuid = UUID().uuidString + "." + filename.fileExtension
            let url = PDFileManager.prepareUrlForPhotoFile(named: uuid, folderName: uploadID)
            try await PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: url,
                options: dependencies.resourceOptions
            )
            return url
        } catch let error as NSError {
            _ = DomainCodeError(error: error) // Log error
            throw PhotosFailureUserError.loadResourceFailed
        }
    }

    private func update(url: URL, to photoID: AnyVolumeIdentifier) async throws -> (NSManagedObjectID, AnyVolumeIdentifier) {
        do {
            return try await dependencies.storageManager.backgroundContextPool.performInContext { moc in
                guard let photo = CoreDataPhoto.fetch(identifier: photoID, in: moc) else {
                    Log.error("Photo not found, id: \(photoID.id)", error: nil, domain: .photosProcessing)
                    assertionFailure("Shouldn't happen")
                    throw Errors.photoNotFound
                }
                photo.photoRevision.normalizedUploadableResourceURL = url
                try moc.saveIfNeeded()
                return (photo.objectID, photo.genericIdentifier)
            }
        } catch {
            if error is Errors {
                Log.error("Missing Photo object from database", error: error, domain: .photosProcessing)
                throw PhotosFailureUserError.accessFileFailed
            } else {
                _ = DomainCodeError(error: error as NSError, message: "Update photo object")
                throw PhotosFailureUserError.accessFileFailed
            }
        }
    }
}

// MARK: - Workaround to restart queue
extension PhotoFeederPreprocessor {
    private func handle(invalidPhotos: [InvalidPhoto]) async throws {
        if invalidPhotos.isEmpty { return }
        let failedIdentifiersResource = dependencies.failedIdentifiersResource
        try await dependencies.storageManager.backgroundContextPool.performInContext { context in
            for photo in invalidPhotos {
                if let cloudIdentifier = photo.cloudIdentifier {
                    failedIdentifiersResource.increment(cloudIdentifier: cloudIdentifier, error: photo.error)
                }
                for objectId in photo.objectIDs {
                    context.delete(context.object(with: objectId))
                }
            }
            try context.saveIfNeeded()
        }
    }

    private func cleanupIfNeeded(pendingCount: Int, processedCount: Int) async {
        // has pending photos and doesn't feed photos to uploader
        guard pendingCount > 0 && processedCount == 0 else { return }

        let uploadingPhotos = await activeUploadsCount()
        // Don't affect uploading photos
        guard uploadingPhotos == 0 else { return }

        isEnabled = false

        Log.error("Feeder clean up triggered", error: nil, domain: .uploader)
        // Upload stuck have been observed starting in version 1.56.0
        // Photos are successfully imported into the database but the upload process never continues
        // In this scenario, the photo state ends up marked as "interrupt"
        // Attempting to limit the impact of this cleanup
        dependencies.folderSizeResource.clearFolder()
        await dependencies.uploadingPhotosRepository.deleteInterruptPhotos()
        isEnabled = true
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [weak self] in
            // Scan library again
            self?.dependencies.retryTriggerController.retry()
        }
    }
}

// MARK: -
extension PhotoFeederPreprocessor {
    @MainActor
    private func activeUploadsCount() -> Int {
        // The SDK feature flag may be disabled at any time.
        // Check both upload counters to avoid interrupting an ongoing SDK upload.

        let sdkUploadingNumber = dependencies.sdkPhotoUploader()?.activeUploadsCount() ?? 0
        return sdkUploadingNumber + dependencies.uploader.getExecutableOperationsCount()
    }

    private func isUnderLimited() async -> Bool {
        let processingPhotos = await activeUploadsCount()
        let isUnderLimited = processingPhotos < dependencies.allowedBatchSize / 2
        if !isUnderLimited {
            Log.info("📸☁️⚠️ Ignore feeding request, Photo upload currently \(processingPhotos) photos in queue (limit: \(dependencies.allowedBatchSize / 2))", domain: .uploader)
        }
        return isUnderLimited
    }
    
    private func fetchPendingPhotos() -> [CoreDataPhoto] {
        if dependencies.featureFlagsController.hasSDKUploadPhoto, let sdkUploader = dependencies.sdkPhotoUploader() {
            return dependencies.uploadingPhotosRepository.getPendingPhotosForSDK()
        } else {
            return dependencies.uploadingPhotosRepository.getPhotos()
        }
    }

    private func upload(photos: [(NSManagedObjectID, AnyVolumeIdentifier)]) {
        // If the SDK feature flag is disabled, fall back to the legacy uploader to keep photo backups running
        if dependencies.featureFlagsController.hasSDKUploadPhoto, let sdkUploader = dependencies.sdkPhotoUploader() {
            let identifiers = photos.map { $0.1 }
            Log.info("Schedule to upload \(photos.count) photos via SDK", domain: .sdk)
            Task {
                await withTaskGroup { group in
                    for identifier in identifiers {
                        group.addTask { try? await sdkUploader.upload(identifier: identifier) }
                    }
                }
            }
        } else {
            Log.info("Schedule to upload \(photos.count) photos via legacy", domain: .uploader)
            // Intentional use newBackgroundContext, so context will be released later to free memory
            let context = dependencies.storageManager.newBackgroundContext()
            context.perform { [weak self, context] in
                let objectIDs = photos.map { $0.0 }
                let photos: [CoreDataPhoto] = objectIDs.compactMap { id in
                    do {
                        return try context.typedObject(with: id)
                    } catch {
                        Log.error("Fetch CoreDataPhoto from NSManagedObjectID failed", error: error, domain: .photosProcessing)
                        return nil
                    }
                }
                self?.dependencies.uploader.upload(files: photos)
            }
        }
    }

    private func resume() async {
        // If the SDK feature flag is disabled, fall back to the legacy uploader to keep photo backups running
        if dependencies.featureFlagsController.hasSDKUploadPhoto, let sdkUploader = dependencies.sdkPhotoUploader() {
            await sdkUploader.resumePausedUploads()
        } else {
            // Legacy doens't support resume
        }
    }
}

extension PhotoFeederPreprocessor {
    public struct Dependencies {
        public let allowedBatchSize: Int
        public let failedIdentifiersResource: DeletedPhotosIdentifierStoreResource
        public let featureFlagsController: FeatureFlagsControllerProtocol
        public let feedPublisher: AnyPublisher<Void, Never>
        public let folderSizeResource: FolderSizeResource
        public let optionsFactory: PHFetchOptionsFactory
        public let photoIdentifierInquirer: PhotoIdentifierInquirer
        public let resourceOptions: PHAssetResourceRequestOptions
        public let retryTriggerController: PhotoLibraryLoadRetryTriggerController
        public let storageManager: StorageManager
        public let sdkPhotoUploader: () -> SDKFileUploaderProtocol?
        public let uploader: PhotoUploader
        public let uploadingPhotosRepository: UploadingPrimaryPhotosRepository

        public init(
            allowedBatchSize: Int,
            failedIdentifiersResource: DeletedPhotosIdentifierStoreResource,
            featureFlagsController: FeatureFlagsControllerProtocol,
            feedPublisher: AnyPublisher<Void, Never>,
            folderSizeResource: FolderSizeResource,
            optionsFactory: PHFetchOptionsFactory,
            photoIdentifierInquirer: PhotoIdentifierInquirer,
            retryTriggerController: PhotoLibraryLoadRetryTriggerController,
            storageManager: StorageManager,
            uploader: PhotoUploader,
            sdkPhotoUploader: @autoclosure @escaping () -> SDKFileUploaderProtocol?,
            uploadingPhotosRepository: UploadingPrimaryPhotosRepository
        ) {
            self.allowedBatchSize = allowedBatchSize
            self.failedIdentifiersResource = failedIdentifiersResource
            self.featureFlagsController = featureFlagsController
            self.feedPublisher = feedPublisher
            self.folderSizeResource = folderSizeResource
            self.optionsFactory = optionsFactory
            self.photoIdentifierInquirer = photoIdentifierInquirer
            self.resourceOptions = PHAssetResourceRequestOptions()
            resourceOptions.isNetworkAccessAllowed = true
            self.retryTriggerController = retryTriggerController
            self.storageManager = storageManager
            self.uploader = uploader
            self.sdkPhotoUploader = sdkPhotoUploader
            self.uploadingPhotosRepository = uploadingPhotosRepository
        }
    }

    enum Errors: Error {
        case photoNotFound
    }

    struct PhotoData {
        let identifier: AnyVolumeIdentifier
        let resourceType: Int
        let decryptedName: String
        let photoObjectID: NSManagedObjectID
        let uploadID: String
    }

    struct Identifier: Hashable {
        let localIdentifier: String?
        let cloudIdentifier: String
    }

    private final class GroupResult {
        /// Photos that resource have been copied to local storage
        var copiedPhotos: [(NSManagedObjectID, AnyVolumeIdentifier)] = []
        /// Photos that need to be copied
        /// Normal photo has 1 PhotoData but modified photo has multiple PhotoData
        var dataToBeCopied: [Identifier: [PhotoData]] = [:]
        /// Photos contain invalid variables
        private(set) var invalidPhotos: [InvalidPhoto] = []
        /// Photos are uploading
        var skippedPhotos: [(NSManagedObjectID, AnyVolumeIdentifier)] = []

        func appendCopiedPhotoData(id: Identifier, data: PhotoData) {
            dataToBeCopied[id, default: []].append(data)
        }

        func append(invalidPhoto: CoreDataPhoto) {
            guard
                let tempBase64Metadata = invalidPhoto.tempBase64Metadata,
                let metadata = TemporalMetadata(base64String: tempBase64Metadata),
                let cloudIdentifier = metadata.iOSPhotos.iCloudID
            else {
                invalidPhotos.append(InvalidPhoto(
                    cloudIdentifier: nil,
                    error: .corruptedAsset,
                    objectIDs: [invalidPhoto.objectID]
                ))
                return
            }

            invalidPhotos.append(InvalidPhoto(
                cloudIdentifier: cloudIdentifier,
                error: .corruptedAsset,
                objectIDs: [invalidPhoto.objectID]
            ))
        }
    }

    private struct InvalidPhoto {
        let cloudIdentifier: String?
        let error: PhotosFailureUserError
        let objectIDs: [NSManagedObjectID]
    }
}
