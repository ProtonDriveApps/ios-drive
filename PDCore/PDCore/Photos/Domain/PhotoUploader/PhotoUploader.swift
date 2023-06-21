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
import Combine

public protocol UploadingPhotosRepository {
    var photos: AnyPublisher<[Photo], Never> { get }
}

public final class PhotoUploader: FileUploader, Uploader {
    private var cancellable: Cancellable?
    private let photosRepository: UploadingPhotosRepository

    public init(
        photosRepository: UploadingPhotosRepository,
        fileUploadFactory: FileUploadOperationsProvider,
        storage: StorageManager,
        sessionVault: SessionVault
    ) {
        self.photosRepository = photosRepository
        super.init(fileUploadFactory: fileUploadFactory, storage: storage, sessionVault: sessionVault)
        subscribeToPhotoUploads()
    }

    private func subscribeToPhotoUploads() {
        self.cancellable = photosRepository.photos
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .sink { [weak self] photos in
                for photo in photos {
                    self?.moc.performAndWait {
                        self?.startUpload(photo)
                    }
                }
            }
    }

    private func startUpload(_ photo: Photo) {
        guard canUploadPhoto(photo) else { return }
        upload(photo, completion: { _ in })
    }

    private func canUploadPhoto(_ photo: Photo) -> Bool {
        guard let id = photo.uploadID,
              getProcessingOperation(with: id) == nil else {
            return false
        }
        return true
    }

    public func stop() {
        cancellAllOperations()
    }

}
