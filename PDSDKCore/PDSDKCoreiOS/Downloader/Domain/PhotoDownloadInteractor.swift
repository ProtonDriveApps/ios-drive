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

import Combine
import CoreData
import PDCore
import ProtonDriveSDK
import PDSDKCore

final class PhotoDownloadInteractor: FileDownloadInteractorProtocol {
    private let operationPerformer: PhotosOperationPerformer
    private let cacheResource: PhotoDownloaderCacheProtocol
    private let managedObjectContext: NSManagedObjectContext

    init(
        operationPerformer: PhotosOperationPerformer,
        cacheResource: PhotoDownloaderCacheProtocol,
        managedObjectContext: NSManagedObjectContext
    ) {
        self.operationPerformer = operationPerformer
        self.cacheResource = cacheResource
        self.managedObjectContext = managedObjectContext
    }

    func download(
        file identifier: AnyVolumeIdentifier,
        cancellationToken: UUID,
        options: SDKFileDownloadOptions,
        progress: @escaping ProgressCallback,
        checkCancellation: @escaping FileDownloadCancellationCheck
    ) async throws {
        let downloadInput = try await cacheResource.getDownloadInput(for: identifier, options: options)
        do {
            // Make sure there's no remainder from previous download
            cacheResource.cleanUp(for: downloadInput)
            // Notify initial progress as soon as we know the clear size
            let initialProgress = FileOperationProgress(bytesCompleted: 0, bytesTotal: Int64(downloadInput.clearSize))
            progress(initialProgress)

            // SDK will download into temporary url
            let destinationUrl = URL(string: downloadInput.temporaryUrl.path(percentEncoded: false))!

            // Check cancellation before SDK is invoked - minimize probability of race condition.
            try await checkCancellation()

            // the verification issues are ignored for now, to keep the behaviour consistent with the legacy pipeline
            _ = try await operationPerformer.downloadPhoto(
                photoUid: identifier.sdkUid,
                destinationUrl: destinationUrl,
                shareID: downloadInput.shareID,
                cancellationToken: cancellationToken,
                progressCallback: progress,
                onRetriableErrorReceived: { _ in },
                shouldThrowOnManifestVerificationIssues: false,
                moc: self.managedObjectContext
            )
            // We will move from temporary url to normal cache url (where revision expects it)
            try cacheResource.finalizeDownload(for: downloadInput)
        } catch {
            cacheResource.cleanUp(for: downloadInput)
            throw error
        }
    }


    func cancel(with cancellationTokens: [UUID]) async {
        for token in cancellationTokens {
            do {
                async let _ = try await operationPerformer.cancelDownload(cancellationToken: token)
            } catch {
                Log.error("Failed to cancel photo download", error: error, domain: .sdk)
            }
        }
    }
}
