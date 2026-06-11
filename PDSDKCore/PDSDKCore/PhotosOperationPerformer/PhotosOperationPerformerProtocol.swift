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
import PDCore
import ProtonDriveSDK

public protocol PhotosOperationPerformerProtocol: FileOperationCancelPerformerProtocol {
    func downloadThumbnailsStream(
        photoUids: [SDKNodeUid],
        type: ThumbnailData.ThumbnailType,
        cancellationToken: UUID,
        moc: NSManagedObjectContext
    ) -> AsyncThrowingStream<ThumbnailDataWithId?, Error>

    func downloadPhoto(
        photoUid: SDKNodeUid,
        destinationUrl: URL,
        shareID: String,
        cancellationToken: UUID,
        progressCallback: @escaping ProgressCallback,
        onRetriableErrorReceived: @Sendable @escaping (Error) -> Void,
        shouldThrowOnManifestVerificationIssues: Bool,
        moc: NSManagedObjectContext
    ) async throws -> VerificationIssue?

    func uploadOperation(
        attributes: PhotoAttributes,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol?,
        progressCallback: @escaping ProgressCallback
    ) async throws -> ProtonDriveSDK.UploadOperation

    func startUpload(
        operation: ProtonDriveSDK.UploadOperation,
        attributes: PhotoAttributes,
        moc: NSManagedObjectContext,
        thumbnailLocalCache: ThumbnailsUploadLocalCacheProtocol?,
        onRetriableErrorReceived: @Sendable @escaping (any Error) -> Void
    ) async throws -> Node
}
