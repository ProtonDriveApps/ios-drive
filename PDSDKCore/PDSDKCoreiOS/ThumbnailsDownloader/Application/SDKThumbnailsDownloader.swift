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

import Combine
import CoreData
import Foundation
import PDCore
import PDSDKCore
import ProtonDriveSDK

actor SDKThumbnailsDownloader: SDKThumbnailsDownloaderProtocol { // Is not needed to be MainActor atm
    private let context: NSManagedObjectContext
    private let fileInteractor: ThumbnailsDownloadInteractor
    private let photoInteractor: ThumbnailsDownloadInteractor
    private let volumeIDRepository: VolumeIDRepository
    private var volumeIDs: StorageManager.VolumeIDs?
    /// [VolumeID: isFile]
    private var volumeInteractorCache: [String: Bool] = [:]
    private var hasReFetchedVolumeID = false
    private weak var contextPool: SyncManagedObjectContextPool?

    init(
        context: NSManagedObjectContext,
        contextPool: SyncManagedObjectContextPool,
        fileInteractor: ThumbnailsDownloadInteractor,
        photoInteractor: ThumbnailsDownloadInteractor,
        volumeIDRepository: VolumeIDRepository
    ) {
        self.context = context
        self.contextPool = contextPool
        self.fileInteractor = fileInteractor
        self.photoInteractor = photoInteractor
        self.volumeIDRepository = volumeIDRepository
    }

    func downloadThumbnail(
        for file: AnyVolumeIdentifier,
        type: ThumbnailType
    ) async throws -> AnyVolumeIdentifier? {
        do {
            let interactor = try await interactor(for: file)
            return try await interactor.downloadThumbnail(file: file, type: type)
        } catch {
            if let sdkError = error as? ProtonDriveSDKError, sdkError.isCancellationError {
                throw SDKDownloadErrors.cancelled
            } else if error is CancellationError {
                throw SDKDownloadErrors.cancelled
            } else if error.localizedDescription.hasSuffix("has no thumbnails") {
                return nil
            }

            Log.error("Failed to download a thumbnail: \(error.localizedDescription)", error: error, domain: .sdk, context: LogContext("fileDescription: \(file.debugDesc)"))
            throw error
        }
    }

    private func interactor(for identifier: AnyVolumeIdentifier) async throws -> ThumbnailsDownloadInteractor {
        let volumeID = identifier.volumeID
        if volumeIDs == nil || (volumeIDs?.photo == nil && !hasReFetchedVolumeID) {
            // For newly registered users, the photo volume isn't created until they log in
            // So immediately after login, the photo volume may still be nil and will be created later
            volumeIDs = try await volumeIDRepository.getVolumeIDs(within: context)
            if volumeIDs?.photo == nil { hasReFetchedVolumeID = true }
        }
        guard let volumeIDs else { throw DriveError("Fetch volumeIDs failed") }
        switch volumeID {
        case volumeIDs.main: return fileInteractor
        case volumeIDs.photo: return photoInteractor
        default:
            if let isFile = volumeInteractorCache[volumeID] {
                return isFile ? fileInteractor : photoInteractor
            }
            let isFile: Bool? = await context.perform { [context] in
                guard let volume = CoreDataVolume.fetch(id: volumeID, in: context) else { return nil }
                let isPhotoVolume = volume.shares.contains { share in
                    share.root is CoreDataPhoto || share.root is CoreDataAlbum
                }
                return !isPhotoVolume
            }
            if let isFile {
                volumeInteractorCache[volumeID] = isFile
            }
            return (isFile ?? true) ? fileInteractor : photoInteractor
        }
    }

    nonisolated func cancel(_ identifiers: [AnyVolumeIdentifier], type: ThumbnailType) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for id in identifiers {
                    group.addTask {
                        do {
                            let interactor = try await self.interactor(for: id)
                            await interactor.cancel(file: id.any(), type: type)
                        } catch {
                            Log.error("Cancel thumbnail download failed", error: error, domain: .sdk)
                        }
                    }
                }
            }
        }
    }

    func cancelAll() async {
        await fileInteractor.cancelAll()
        await photoInteractor.cancelAll()
    }

    deinit {
        contextPool?.relinquish(context)
    }
}
