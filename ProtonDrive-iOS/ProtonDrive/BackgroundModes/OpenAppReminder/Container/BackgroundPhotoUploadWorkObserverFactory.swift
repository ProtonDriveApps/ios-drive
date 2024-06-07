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

import PDCore

final class BackgroundPhotoUploadWorkObserverFactory {
    struct Dependencies {
        var scheduledPhotosUploadWorkerState: WorkerState
        var coredataLastPhotoRepository: LastPhotoRepository
        var galleryLastPhotoRepository: LastPhotoRepository
    }

    func makeBackgroundUploadWorkerState(_ dependencies: Dependencies) -> WorkerState {
        // Photos that we are currently uploading processing pipeline + photo uploader
        let scheduledPhotosUploadWorkObserver = dependencies.scheduledPhotosUploadWorkerState

        // Last non-backed up photo in the gallery, comparison between coredata db and user gallery
        let nonSetupPhotoUploadsWorker = NewPhotosFinderController(backedUpPhotoRepository: dependencies.coredataLastPhotoRepository, galleryPhotoRepository: dependencies.galleryLastPhotoRepository)

        // Checks if we are actively uploading a photo, if not we check if there is a non-backed up photo in the gallery
        return UploadWorkerStateComposite(primaryWorker: scheduledPhotosUploadWorkObserver, secondaryWorker: nonSetupPhotoUploadsWorker)
    }
}
