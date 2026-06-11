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
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonDriveSDK
import PDClient
@preconcurrency import PDCore
import ProtonCoreUtilities
import CoreData
import FileProvider

// swiftlint:disable:next function_parameter_count

/// SDK-based implementations of FileProvider operations.
public final class FileOperationPerformer: FileOperationCancelPerformerProtocol, AdditionalDataLogger {
    private let client: ProtonDriveClient
    private let metadataUpdater: MetadataUpdaterProtocol
    private let observabilityReporter: ObservabilityReporterProtocol
    private let fileVerifier: FileVerificationProtocol
    private let featureFlagProviderCallback: FeatureFlagProviderCallback

    public init(
        protonDriveClientConfiguration: ProtonDriveClientConfiguration,
        storage: StorageManager,
        networking: MetadataUpdaterAwareHttpCallExecutor,
        accountClient: AccountClientProtocol,
        httpResilience: HttpResilienceConfigurationProvider = DefaultHttpResilienceConfigurationProvider.instance,
        rateLimitGate: RateLimitGate,
        urlCacheCleaner: URLCacheCleanerProtocol,
        fileVerifier: FileVerificationProtocol,
        observabilityReporter: ObservabilityReporterProtocol,
        featureFlagProviderCallback: @escaping FeatureFlagProviderCallback
    ) async throws {
        self.metadataUpdater = MetadataUpdater(storage: storage)
        self.observabilityReporter = observabilityReporter
        self.fileVerifier = fileVerifier
        self.featureFlagProviderCallback = featureFlagProviderCallback
        self.client = try await ProtonDriveClient(
            configuration: protonDriveClientConfiguration,
            httpClient: HttpClient(apiService: networking,
                                   metadataUpdater: metadataUpdater,
                                   httpResilience: httpResilience,
                                   urlCacheCleaner: urlCacheCleaner,
                                   rateLimitGate: rateLimitGate),
            accountClient: accountClient,
            logCallback: { logEvent in
                Log.log(LogLevel(sdkLogLevel: logEvent.level), message: logEvent.message, domain: .sdk, function: "logCallback")
            },
            recordMetricEventCallback: { [weak observabilityReporter] metricEvent in
                observabilityReporter?.handle(event: metricEvent)
            },
            featureFlagProviderCallback: featureFlagProviderCallback
        )
    }

    public func uploadFile(
        parentFolderUid: SDKNodeUid,
        name: String,
        conflictedName: String? = nil,
        url: URL, // Contains path string, not `file://` file path
        fileAttributes: FileAttributes,
        shareID: String,
        mediaType: String,
        cancellationToken: UUID,
        progressCallback: @escaping ProgressCallback,
        onRetriableErrorReceived: @Sendable @escaping (Error) -> Void,
        moc: NSManagedObjectContext,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol? = nil,
        conflictResolution: ConflictResolution,
        onUploadOperationChange: ((ProtonDriveSDK.UploadOperation?) async -> Void)? = nil
    ) async throws -> Node {
        try await metadataUpdater.withOperation {
            do {
                let expectedSha1: Data?
                if await !self.isUploadVerificationDisabled {
                    do {
                        expectedSha1 = try await self.fileVerifier.computeDigestData(file: url)
                        await self.observabilityReporter.reportFileVerification(.upload(sha1Provided: true))
                    } catch {
                        Log.error("Failed to compute SHA1 for upload verification", error: error, domain: .sdk)
                        expectedSha1 = nil
                        await self.observabilityReporter.reportFileVerification(.upload(sha1Provided: false))
                    }
                } else {
                    expectedSha1 = nil
                }
                let fileURL = URL(fileURLWithPath: url.path(percentEncoded: false))
                let thumbnailData = await thumbnailProvider.defaultThumbnailData(fileUrl: fileURL, overrideMediaType: mediaType)
                let thumbnails: [ThumbnailData] = thumbnailData.map { [ThumbnailData(type: .thumbnail, data: $0)] } ?? []

                await self.storeTemporaryThumbnails(
                    parentFolderUid: parentFolderUid,
                    cancellationToken: cancellationToken,
                    thumbnails: thumbnails,
                    thumbnailLocalCache: thumbnailLocalCache
                )

                let filename = conflictedName ?? name
                let operation = try await self.client.uploadFileOperation(
                    parentFolderUid: parentFolderUid,
                    name: filename,
                    url: url,
                    fileSize: fileAttributes.fileSize,
                    modificationDate: fileAttributes.modificationDate,
                    mediaType: mediaType,
                    thumbnails: thumbnails,
                    overrideExistingDraft: false,
                    expectedSHA1: expectedSha1,
                    cancellationToken: cancellationToken,
                    progressCallback: progressCallback
                )
                // Notify caller that the upload registered new operation (this can be invoked multiple times in case of name conflicts resolution)
                await onUploadOperationChange?(operation)

                return try await self.startUpload(
                    operation: operation,
                    parentFolderUid: parentFolderUid,
                    url: url,
                    fileAttributes: fileAttributes,
                    cancellationToken: cancellationToken,
                    moc: moc,
                    thumbnailLocalCache: thumbnailLocalCache,
                    onRetriableErrorReceived: onRetriableErrorReceived
                )
            } catch let error as ProtonDriveSDKError {
                if error.isConflictError, let nameError = error.additionalErrorData as? NodeNameConflictErrorData {
                    await onUploadOperationChange?(nil)
                    switch conflictResolution {
                    case .newFile:
                        let newName = try await self.client.getAvailableName(
                            parentFolderUid: parentFolderUid,
                            name: name,
                            cancellationToken: cancellationToken
                        )
                        return try await self.uploadFile(
                            parentFolderUid: parentFolderUid,
                            name: name,
                            conflictedName: newName,
                            url: url,
                            fileAttributes: fileAttributes,
                            shareID: shareID,
                            mediaType: mediaType,
                            cancellationToken: cancellationToken,
                            progressCallback: progressCallback,
                            onRetriableErrorReceived: onRetriableErrorReceived,
                            moc: moc,
                            thumbnailProvider: thumbnailProvider,
                            thumbnailLocalCache: thumbnailLocalCache,
                            conflictResolution: conflictResolution,
                            onUploadOperationChange: onUploadOperationChange
                        )
                    case .newRevision:
                        if nameError.isFileDraft { throw error }
                        guard let revisionUid = nameError.revisionUID else { throw error }
                        return try await self.uploadNewRevision(
                            currentActiveRevisionUid: revisionUid,
                            url: url,
                            fileAttributes: fileAttributes,
                            shareID: shareID,
                            thumbnailProvider: thumbnailProvider,
                            cancellationToken: cancellationToken,
                            thumbnailsUploadLocalCache: thumbnailLocalCache,
                            progressCallback: progressCallback,
                            onRetriableErrorReceived: onRetriableErrorReceived,
                            moc: moc
                        )
                    case .undetermined:
                        throw error
                    }
                } else if let dataIntegrityError = error.underlyingDataIntegrityError,
                          case let .contentUploadIntegrity(message, _, _) = dataIntegrityError {
                    Log.error(message, domain: .sdk, sendToSentryIfPossible: true)
                    throw FileVerificationError.uploadVerificationFailed(underlyingCause: message)
                } else {
                    throw error
                }
                throw error
            }
        }
    }

    public func startUpload(
        operation: ProtonDriveSDK.UploadOperation,
        parentFolderUid: SDKNodeUid,
        url: URL, // Contains path string, file://..../abc.png
        fileAttributes: FileAttributes,
        cancellationToken: UUID,
        moc: NSManagedObjectContext,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol?,
        onRetriableErrorReceived: @Sendable @escaping (Error) -> Void
    ) async throws -> Node {
        try await metadataUpdater.withOperation {
            let result: UploadedFileIdentifiers
            do {
                result = try await self.client.startUpload(
                    operation: operation,
                    onRetriableErrorReceived: onRetriableErrorReceived
                )
            } catch {
                let context = [
                    "UploadID": cancellationToken.uuidString,
                    "Expected file size in bytes": fileAttributes.fileSize.formatted(),
                    "URL file size in bytes": url.fileSize?.formatted() ?? "Unknown",
                    "Masked filename": url.maskFilename()
                ]
                self.logAdditionalDataInSDKError(error, context: context, file: #file, function: "StartUpload", line: #line)
                throw error
            }

            self.moveTemporaryThumbnails(nodeUid: result.nodeUid, cancellationToken: cancellationToken, thumbnailLocalCache: thumbnailLocalCache)

            #if os(macOS)
            let node = try await self.metadataUpdater.finishFileUpload(
                parentFolderUid: parentFolderUid,
                size: Int(fileAttributes.fileSize),
                fileURL: url,
                creationDate: fileAttributes.creationDate.timeIntervalSince1970,
                modificationDate: fileAttributes.modificationDate.timeIntervalSince1970,
                result: result,
                moc: moc
            )
            #else
            let node = try await self.metadataUpdater.finishIOSFileUpload(
                parentFolderUid: parentFolderUid,
                uploadID: cancellationToken,
                size: Int(fileAttributes.fileSize),
                fileURL: url,
                creationDate: fileAttributes.creationDate.timeIntervalSince1970,
                modificationDate: fileAttributes.modificationDate.timeIntervalSince1970,
                result: result,
                moc: moc
            )
            #endif
            return node
        }
    }

    public func uploadNewRevision(
        currentActiveRevisionUid: SDKRevisionUid,
        url: URL, // Contains path string, not `file://` file path
        fileAttributes: FileAttributes,
        shareID: String,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol,
        cancellationToken: UUID,
        thumbnailsUploadLocalCache: ThumbnailsUploadLocalCacheProtocol? = nil,
        progressCallback: @escaping ProgressCallback,
        onRetriableErrorReceived: @Sendable @escaping (Error) -> Void,
        moc: NSManagedObjectContext
    ) async throws -> Node {
        try await metadataUpdater.withOperation {
            let expectedSha1: Data?
            if await !self.isUploadVerificationDisabled {
                do {
                    expectedSha1 = try await self.fileVerifier.computeDigestData(file: url)
                    await self.observabilityReporter.reportFileVerification(.upload(sha1Provided: true))
                } catch {
                    Log.error("Failed to compute SHA1 for revision upload verification", error: error, domain: .sdk)
                    expectedSha1 = nil
                    await self.observabilityReporter.reportFileVerification(.upload(sha1Provided: false))
                }
            } else {
                expectedSha1 = nil
            }
            let fileURL = URL(fileURLWithPath: url.path(percentEncoded: false))
            let thumbnails: [ThumbnailData] = await thumbnailProvider.defaultThumbnailData(fileUrl: fileURL, overrideMediaType: nil).map { data in
                [ThumbnailData(type: .thumbnail, data: data)]
            } ?? []
            await thumbnailsUploadLocalCache?.save(
                thumbnails: thumbnails,
                tempID: currentActiveRevisionUid.nodeID,
                volumeID: currentActiveRevisionUid.volumeID
            )
            do {
                let result = try await self.client.uploadNewRevision(
                    currentActiveRevisionUid: currentActiveRevisionUid,
                    fileURL: url,
                    fileSize: fileAttributes.fileSize,
                    modificationDate: fileAttributes.modificationDate,
                    thumbnails: thumbnails,
                    expectedSHA1: expectedSha1,
                    cancellationToken: cancellationToken,
                    progressCallback: progressCallback,
                    onRetriableErrorReceived: onRetriableErrorReceived
                )
                let node = try await self.metadataUpdater.finishNewRevisionUpload(
                    result: result,
                    size: Int(fileAttributes.fileSize),
                    creationDate: fileAttributes.creationDate,
                    shareID: shareID,
                    uploadID: cancellationToken,
                    moc: moc
                )
                return node
            } catch let error as ProtonDriveSDKError {
                if let dataIntegrityError = error.underlyingDataIntegrityError,
                   case let .contentUploadIntegrity(message, _, additionalData) = dataIntegrityError {
                    Log.error(message, domain: .sdk, sendToSentryIfPossible: true)
                    Log.debug("ContentUploadIntegrity additional error data: \(additionalData ?? "")", domain: .sdk)
                    throw FileVerificationError.uploadVerificationFailed(underlyingCause: message)
                } else {
                    throw error
                }
            } catch {
                throw error
            }
        }
    }

    public func downloadFile(
        revisionUid: SDKRevisionUid,
        destinationUrl: URL,
        shareID: String,
        cancellationToken: UUID,
        progressCallback: @escaping ProgressCallback,
        onRetriableErrorReceived: @Sendable @escaping (Error) -> Void,
        shouldThrowOnManifestVerificationIssues: Bool,
        moc: NSManagedObjectContext
    ) async throws -> (PDCore.Revision, VerificationIssue?) {
        try await metadataUpdater.withOperation {
            do {
                let potentialManifestVerificationIssue = try await self.client.downloadFile(
                    revisionUid: revisionUid,
                    destinationUrl: destinationUrl,
                    cancellationToken: cancellationToken,
                    progressCallback: progressCallback,
                    onRetriableErrorReceived: onRetriableErrorReceived
                )
                if let manifestVerificationIssue = potentialManifestVerificationIssue,
                   shouldThrowOnManifestVerificationIssues {
                    throw manifestVerificationIssue
                }
                let revision = try await self.metadataUpdater.finishFileDownload(
                    revisionUid: revisionUid,
                    destinationUrl: destinationUrl,
                    shareID: shareID,
                    moc: moc
                )

                if await !self.isDownloadVerificationDisabled {
                    let (expectedSHA1Value, revisionCreationTime, revisionSize, checksumVerified) = await self.extractVerificationInfo(
                        revision: revision, moc: moc
                    )
                    try await self.fileVerifier.verifyDigest(
                        file: destinationUrl,
                        against: expectedSHA1Value,
                        revisionUid: revisionUid.sdkCompatibleIdentifier,
                        revisionCreationTime: revisionCreationTime,
                        revisionSize: Int64(revisionSize),
                        checksumVerified: checksumVerified
                    )
                }
                return (revision, potentialManifestVerificationIssue)
            } catch {
                // verification failure does not remove the updated info from metadata DB
                // we should have the latest node and revision metadata saved in the DB, even if the verification fails

                try? FileManager.default.removeItem(at: destinationUrl)

                throw error

            }
        }
    }

    public func downloadThumbnailsStream(
        fileUids: [SDKNodeUid],
        type: ThumbnailData.ThumbnailType,
        cancellationToken: UUID,
        moc: NSManagedObjectContext
    ) -> AsyncThrowingStream<ThumbnailDataWithId?, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: ThumbnailDataWithId?.self)

        // Bare beginOperation/endOperation pair: stream lifetime can outlive any single closure,
        // so we hand-roll the bracketing instead of using `withOperation`. The capture below holds
        // `metadataUpdater` strongly so `endOperation` fires even if `self` is released first.
        let metadataUpdater = self.metadataUpdater
        metadataUpdater.beginOperation()

        let task = Task { [weak self] in
            guard let self else {
                continuation.finish(throwing: Errors.selfIsReleased)
                return
            }

            let buffer = AsyncThrowingStream.makeStream(of: ThumbnailDataWithId?.self)

            let sdkTask = Task {
                do {
                    try await self.client.downloadThumbnails(
                        fileUids: fileUids,
                        type: type,
                        cancellationToken: cancellationToken,
                        onThumbnailDownloaded: { result in
                            switch result {
                            case .success(let data):
                                buffer.1.yield(data)
                            case .failure(let error):
                                buffer.1.finish(throwing: error)
                            }
                        }
                    )
                    buffer.1.finish()
                } catch {
                    buffer.1.finish(throwing: error)
                }
            }

            do {
                for try await thumbnail in buffer.0 {
                    if let thumbnail {
                        try await self.metadataUpdater.finishFileThumbnailDownload(fileUid: thumbnail.fileUid, moc: moc)
                    } else {
                        Log.warning("Get nil ThumbnailDataWithId", domain: .sdk)
                    }
                    continuation.yield(thumbnail)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
                sdkTask.cancel()
            }
        }

        continuation.onTermination = { @Sendable _ in
            task.cancel()
            metadataUpdater.endOperation()
        }
        return stream
    }

    public func cancelDownload(cancellationToken: UUID) async throws {
        try await client.cancelDownload(cancellationToken: cancellationToken)
    }

    public func cancelUpload(cancellationToken: UUID) async throws {
        try await client.cancelUpload(cancellationToken: cancellationToken)
    }
}

// MARK: - Node actions
extension FileOperationPerformer {
    public func rename(
        nodeUid: SDKNodeUid,
        newName: String,
        newMediaType: String?,
        cancellationToken: UUID,
        moc: NSManagedObjectContext
    ) async throws {
        try await metadataUpdater.withOperation {
            try await self.client.rename(
                nodeUid: nodeUid,
                newName: newName,
                newMediaType: newMediaType,
                cancellationToken: cancellationToken
            )
            try await self.metadataUpdater.finishRename(nodeUid: nodeUid, moc: moc)
        }
    }

    public func createFolder(
        parentFolderUid: SDKNodeUid,
        folderName: String,
        lastModificationTime: Date,
        resolveConflictByRenaming: Bool,
        moc: NSManagedObjectContext,
        cancellationToken: UUID
    ) async throws -> CoreDataFolder {
        try await metadataUpdater.withOperation {
            do {
                let result = try await self.client.createFolder(
                    parentFolderUid: parentFolderUid,
                    folderName: folderName,
                    lastModificationTime: lastModificationTime,
                    cancellationToken: cancellationToken
                )
                return try await self.metadataUpdater.finishCreateFolder(folderNode: result, moc: moc)

            } catch let error as ProtonDriveSDKError {
                guard error.isConflictError, resolveConflictByRenaming
                else { throw error }

                let newFolderName = try await self.client.getAvailableName(
                    parentFolderUid: parentFolderUid,
                    name: folderName,
                    cancellationToken: UUID()
                )
                return try await self.createFolder(
                    parentFolderUid: parentFolderUid,
                    folderName: newFolderName,
                    lastModificationTime: lastModificationTime,
                    resolveConflictByRenaming: resolveConflictByRenaming,
                    moc: moc,
                    cancellationToken: cancellationToken
                )
            } catch {
                throw error
            }
        }
    }
}

#if os(macOS)
extension FileOperationPerformer {
    public func trash(
        nodes: [SDKNodeUid],
        cancellationToken: UUID,
        moc: NSManagedObjectContext
    ) async throws {
        if nodes.isEmpty { return }
        _ = try await client.trash(nodes: nodes, cancellationToken: cancellationToken)
        try await metadataUpdater.finishTrashMacNodes(nodes: nodes, moc: moc)
    }
}
#else
extension FileOperationPerformer {
    public func trash(
        nodes: [SDKNodeUid],
        cancellationToken: UUID,
        moc: NSManagedObjectContext
    ) async throws -> ([AnyVolumeIdentifier], Error?) {
        if nodes.isEmpty { return ([], nil) }
        let results = try await client.trash(nodes: nodes, cancellationToken: cancellationToken)
        let result = try await metadataUpdater.finishTrashIOSNodes(nodes: nodes, results: results, moc: moc)
        return result
    }
}
#endif

// Helpers

extension FileOperationPerformer {

    private var isDownloadVerificationDisabled: Bool {
        get async {
            await withCheckedContinuation { continuation in
                featureFlagProviderCallback(ExternalFeatureFlag.driveDownloadVerificationDisabled.rawValue) { enabled in
                    continuation.resume(returning: enabled)
                }
            }
        }
    }

    private var isUploadVerificationDisabled: Bool {
        get async {
            await withCheckedContinuation { continuation in
                featureFlagProviderCallback(ExternalFeatureFlag.driveUploadVerificationDisabled.rawValue) { enabled in
                    continuation.resume(returning: enabled)
                }
            }
        }
    }

    private func extractVerificationInfo(
        revision: PDCore.Revision,
        moc: NSManagedObjectContext
    ) async -> (String?, Date?, Int, Bool) {
        return await moc.perform {
            let creationTime = revision.created
            let size = revision.size
            do {
                let attributes = try revision.decryptedExtendedAttributes()
                let sha1 = attributes.common?.digests?.sha1
                let checksumVerified = revision.checksumVerified ?? false
                assert(revision.checksumVerified != nil)
                return (sha1, creationTime, size, checksumVerified)
            } catch {
                return (nil, creationTime, size, false)
            }
        }
    }

    private func storeTemporaryThumbnails(
        parentFolderUid: SDKNodeUid,
        cancellationToken: UUID,
        thumbnails: [ThumbnailData],
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol?
    ) async {
        guard let thumbnailLocalCache else {
            return
        }
        let tempNodeID = cancellationToken.uuidString
        let volumeID = parentFolderUid.volumeID
        await thumbnailLocalCache.save(thumbnails: thumbnails, tempID: tempNodeID, volumeID: volumeID)
    }

    private func moveTemporaryThumbnails(
        nodeUid: SDKNodeUid,
        cancellationToken: UUID,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol?
    ) {
        guard let thumbnailLocalCache else {
            return
        }
        let tempNodeID = cancellationToken.uuidString
        let volumeID = nodeUid.volumeID
        thumbnailLocalCache.moveTempThumbnails(from: tempNodeID, to: nodeUid.nodeID, volumeID: volumeID)
    }
}

extension FileOperationPerformer {
    enum Errors: Error {
        case selfIsReleased
    }
}
