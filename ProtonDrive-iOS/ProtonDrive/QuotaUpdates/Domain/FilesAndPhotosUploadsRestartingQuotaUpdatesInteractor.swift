// Copyright (c) 2023 Proton AG
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
import PDCore

final class FilesAndPhotosUploadsRestartingQuotaUpdatesInteractor: QuotaUpdatesInteractor {
    let photosUploader: SDKFileUploaderProtocol?
    let fileUploader: SDKFileUploaderProtocol
    let storage: StorageManager

    init(photosUploader: SDKFileUploaderProtocol?, fileUploader: SDKFileUploaderProtocol, storage: StorageManager) {
        self.photosUploader = photosUploader
        self.fileUploader = fileUploader
        self.storage = storage
    }

    func availableSpaceDidChangeTo(_ freeSpace: Int) {
        var storageLeft = freeSpace

        let waitingFiles = storage.fetchWaitingFiles(maxSize: storageLeft)
        var fileIDs: [AnyVolumeIdentifier] = []
        for waitingFile in waitingFiles {
            guard storageLeft > Constants.Photos.minimalSpaceForAllowingUpload else { break }
            storageLeft -= waitingFile.size
            fileIDs.append(waitingFile.file.genericIdentifier)
        }
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                for id in fileIDs {
                    _ = try await fileUploader.upload(identifier: id)
                }
            } catch {
                Log.error("Upload file after quota update failed", error: error, domain: .uploader)
            }
        }

        guard storageLeft > 0, let photosUploader else { return }

        let waitingPhotos = storage.fetchMyWaitingPhotos(maxSize: storageLeft)
        var photoIDs: [AnyVolumeIdentifier] = []
        for waitingPhoto in waitingPhotos {
            guard storageLeft > Constants.Photos.minimalSpaceForAllowingUpload else { break }
            storageLeft -= waitingPhoto.size
            photoIDs.append(waitingPhoto.photo.genericIdentifier)
        }
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                for id in photoIDs {
                    _ = try await photosUploader.upload(identifier: id)
                }
            } catch {
                Log.error("Upload file after quota update failed", error: error, domain: .uploader)
            }
        }
    }
}
