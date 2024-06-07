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
    let photosUploader: FileUploader?
    let fileUploader: FileUploader
    let storage: StorageManager

    init(photosUploader: FileUploader?, fileUploader: FileUploader, storage: StorageManager) {
        self.photosUploader = photosUploader
        self.fileUploader = fileUploader
        self.storage = storage
    }

    func availableSpaceDidChangeTo(_ freeSpace: Int) {
        var storageLeft = freeSpace

        let waitingFiles = storage.fetchWaitingFiles(maxSize: storageLeft)
        for waitingFile in waitingFiles {
            guard storageLeft > Constants.minimalSpaceForAllowingUpload else { break }
            storageLeft -= waitingFile.size
            fileUploader.upload(waitingFile.file) { _ in }
        }

        guard storageLeft > 0 else { return }

        let waitingPhotos = storage.fetchWaitingPhotos(maxSize: storageLeft)
        for waitingPhoto in waitingPhotos {
            guard storageLeft > Constants.minimalSpaceForAllowingUpload else { break }
            storageLeft -= waitingPhoto.size
            photosUploader?.upload(waitingPhoto.photo) { _ in }
        }
    }
}
