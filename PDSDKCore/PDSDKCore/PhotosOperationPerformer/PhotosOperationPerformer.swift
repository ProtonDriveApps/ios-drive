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
import Foundation
@preconcurrency import PDCore
import PDClient
import ProtonDriveSDK

public final class PhotosOperationPerformer: PhotosOperationPerformerProtocol, AdditionalDataLogger {
    private let metadataUpdater: MetadataUpdaterProtocol
    private let observabilityReporter: ObservabilityReporterProtocol
    private let client: ProtonPhotosClient
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
        let httpClient = HttpClient(
            apiService: networking,
            metadataUpdater: metadataUpdater,
            httpResilience: httpResilience,
            urlCacheCleaner: urlCacheCleaner,
            rateLimitGate: rateLimitGate
        )
        self.client = try await ProtonPhotosClient(
            configuration: protonDriveClientConfiguration,
            httpClient: httpClient,
            accountClient: accountClient,
            logCallback: { logEvent in
                Log.log(LogLevel(sdkLogLevel: logEvent.level), message: logEvent.message, domain: .sdk, function: "logCallback")
            },
            featureFlagProviderCallback: featureFlagProviderCallback,
            recordMetricEventCallback: { [weak observabilityReporter] metricEvent in
                observabilityReporter?.handle(event: metricEvent)
            }
        )
    }

    /// Experimental
    public func enumerateTimeline(in folderUid: SDKNodeUid) async throws -> [PhotoTimelineItem] {
        // TODO(SDK): write to db?
        try await client.enumerateTimeline(in: folderUid)
    }
}

// MARK: - Download
extension PhotosOperationPerformer {
    public func downloadThumbnailsStream(
        photoUids: [SDKNodeUid],
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
                        photoUids: photoUids,
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
                        try await self.metadataUpdater.finishPhotoThumbnailDownload(fileUid: thumbnail.fileUid, moc: moc)
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

    public func downloadPhoto(
        photoUid: SDKNodeUid,
        destinationUrl: URL,
        shareID: String,
        cancellationToken: UUID,
        progressCallback: @escaping ProgressCallback,
        onRetriableErrorReceived: @Sendable @escaping (Error) -> Void,
        shouldThrowOnManifestVerificationIssues: Bool,
        moc: NSManagedObjectContext
    ) async throws -> VerificationIssue? {
        try await metadataUpdater.withOperation {
            do {
                let potentialManifestVerificationIssue = try await self.client.download(
                    photoUid: photoUid,
                    destinationUrl: destinationUrl,
                    cancellationToken: cancellationToken,
                    progressCallback: progressCallback,
                    onRetriableErrorReceived: onRetriableErrorReceived
                )
                if let manifestVerificationIssue = potentialManifestVerificationIssue,
                    shouldThrowOnManifestVerificationIssues {
                    throw manifestVerificationIssue
                }

                let revision = try await self.metadataUpdater.finishPhotoDownload(
                    photoUid: photoUid, destinationUrl: destinationUrl, shareID: shareID, moc: moc
                )

                if await !self.isDownloadVerificationDisabled {
                    let (revisionID, expectedSHA1Value, revisionCreationTime, revisionSize, checksumVerified) = await self.extractVerificationInfo(
                        revision: revision, moc: moc
                    )

                    try await self.fileVerifier.verifyDigest(
                        file: destinationUrl,
                        against: expectedSHA1Value,
                        revisionUid: SDKRevisionUid(sdkNodeUid: photoUid, revisionID: revisionID).sdkCompatibleIdentifier,
                        revisionCreationTime: revisionCreationTime,
                        revisionSize: Int64(revisionSize),
                        checksumVerified: checksumVerified
                    )
                }
                return potentialManifestVerificationIssue
            } catch {
                // verification failure does not remove the updated info from metadata DB
                // we should have the latest node and revision metadata saved in the DB, even if the verification fails

                try? FileManager.default.removeItem(at: destinationUrl)

                throw error
            }
        }
    }

    public func cancelDownload(cancellationToken: UUID) async throws {
        try await client.cancelPhotoDownload(cancellationToken: cancellationToken)
    }

    private var isDownloadVerificationDisabled: Bool {
        get async {
            await withCheckedContinuation { continuation in
                featureFlagProviderCallback(ExternalFeatureFlag.driveDownloadVerificationDisabled.rawValue) { enabled in
                    continuation.resume(returning: enabled)
                }
            }
        }
    }

    private func extractVerificationInfo(
        revision: PDCore.Revision,
        moc: NSManagedObjectContext
    ) async -> (String, String?, Date?, Int, Bool) {
        return await moc.perform {
            let revisionID = revision.id
            let creationTime = revision.created
            let size = revision.size
            let attributes = try? revision.decryptedExtendedAttributes()
            let sha1 = attributes?.common?.digests?.sha1
            let checksumVerified = revision.checksumVerified ?? false
            assert(revision.checksumVerified != nil)
            return (revisionID, sha1, creationTime, size, checksumVerified)
        }
    }
}

// MARK: - Upload
extension PhotosOperationPerformer {
    public func uploadOperation(
        attributes: PhotoAttributes,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol? = nil,
        progressCallback: @escaping ProgressCallback
    ) async throws -> ProtonDriveSDK.UploadOperation {
        let expectedSha1: Data?
        if await !isUploadVerificationDisabled {
            do {
                expectedSha1 = try await fileVerifier.computeDigestData(file: attributes.fileURL)
                await observabilityReporter.reportFileVerification(.upload(sha1Provided: true))
            } catch {
                Log.error("Failed to compute SHA1 for upload verification", error: error, domain: .sdk)
                expectedSha1 = nil
                await observabilityReporter.reportFileVerification(.upload(sha1Provided: false))
            }
        } else {
            expectedSha1 = nil
        }

        let thumbnails = await makeThumbnails(
            from: attributes.fileURL,
            thumbnailProvider: thumbnailProvider,
        )
        await thumbnailLocalCache?.save(
            thumbnails: thumbnails,
            tempID: attributes.identifier.id,
            volumeID: attributes.identifier.volumeID
        )
        return try await client.uploadOperation(
            name: attributes.name,
            fileURL: attributes.fileURL,
            fileSize: attributes.fileSize,
            modificationDate: attributes.modificationDate,
            captureTime: attributes.captureTime,
            mainPhotoUid: attributes.mainPhotoUid,
            mediaType: attributes.mediaType,
            thumbnails: thumbnails,
            tags: attributes.tags,
            additionalMetadata: attributes.additionalMetadata,
            expectedSHA1: expectedSha1,
            cancellationToken: attributes.uploadID,
            progressCallback: progressCallback
        )
    }

    public func startUpload(
        operation: ProtonDriveSDK.UploadOperation,
        attributes: PhotoAttributes,
        moc: NSManagedObjectContext,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol? = nil,
        onRetriableErrorReceived: @Sendable @escaping (any Error) -> Void
    ) async throws -> Node {
        try await metadataUpdater.withOperation {
            Log.debug("Starting upload: \(attributes.uploadID)", domain: .sdk)
            let result: UploadedFileIdentifiers
            do {
                result = try await client.startUpload(
                    operation: operation,
                    onRetriableErrorReceived: onRetriableErrorReceived
                )
            } catch {
                let context = [
                    "UploadID": attributes.uploadID.uuidString,
                    "Cloud Identifier": attributes.cloudIdentifier,
                    "Expected file size in bytes": attributes.fileSize.formatted(),
                    "URL file size in bytes": attributes.fileURL.fileSize?.formatted() ?? "Unknown",
                    "Masked filename": attributes.name.maskFilename()
                ]
                logAdditionalDataInSDKError(error, context: context, file: #file, function: "startUpload", line: #line)
                throw error
            }
            
            Log.debug("Upload finished, moving thumbnails: \(attributes.uploadID): \(attributes.uploadID)", domain: .sdk)
            thumbnailLocalCache?.moveTempThumbnails(
                from: attributes.identifier.id,
                to: result.nodeUid.nodeID,
                volumeID: result.nodeUid.volumeID
            )
            Log.debug("Moving thumbnails finished, recording to metadata DB: \(attributes.uploadID)", domain: .sdk)
            #if os(macOS)
            let node = try await metadataUpdater.finishFileUpload(
                parentFolderUid: attributes.parentFolderIdentifier,
                size: Int(attributes.fileSize),
                fileURL: attributes.fileURL,
                creationDate: attributes.captureTime.timeIntervalSince1970,
                modificationDate: attributes.modificationDate.timeIntervalSince1970,
                result: result,
                moc: moc
            )
            #else
            let node = try await metadataUpdater.finishIOSFileUpload(
                parentFolderUid: attributes.parentFolderIdentifier,
                uploadID: attributes.uploadID,
                size: Int(attributes.fileSize),
                fileURL: attributes.fileURL,
                creationDate: attributes.captureTime.timeIntervalSince1970,
                modificationDate: attributes.modificationDate.timeIntervalSince1970,
                result: result,
                moc: moc
            )
            #endif
            Log.debug("Finished, returning node: \(attributes.uploadID)", domain: .sdk)
            return node
        }
    }

    public func cancelUpload(cancellationToken: UUID) async throws {
        try await client.cancelUpload(with: cancellationToken)
    }

    private func makeThumbnails(
        from fileURL: URL,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol
    ) async -> [ThumbnailData] {
        var thumbnailData: [ThumbnailData] = []

        if let data = await thumbnailProvider.defaultThumbnailData(fileUrl: fileURL, overrideMediaType: nil) {
            thumbnailData.append(.init(type: .thumbnail, data: data))
        }
        if let data = await thumbnailProvider.photoThumbnailData(fileUrl: fileURL, overrideMediaType: nil) {
            thumbnailData.append(.init(type: .preview, data: data))
        }
        if thumbnailData.isEmpty {
            Log.error("Failed to create photo thumbnail(s) for extension: \(fileURL.pathExtension)", error: nil, domain: .sdk)
        }
        return thumbnailData
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
}

extension PhotosOperationPerformer {
    enum Errors: Error {
        case selfIsReleased
    }
}
