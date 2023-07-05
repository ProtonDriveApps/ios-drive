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
import CoreData

public final class PhotoUploader: FileUploader, Uploader {
    private var cancellable: Cancellable?
    private let photosRepository: UploadingPhotosRepository
    private let throttle: DispatchQueue.SchedulerTimeType.Stride

    public init(
        photosRepository: UploadingPhotosRepository,
        photoUploadAvailabilityController: PhotosBackupUploadAvailableController,
        operationsProvider: FileUploadOperationsProvider,
        throttle: DispatchQueue.SchedulerTimeType.Stride = 1,
        storage: StorageManager,
        sessionVault: SessionVault,
        moc: NSManagedObjectContext
    ) {
        self.throttle = throttle
        self.photosRepository = photosRepository
        super.init(concurrentOperations: 1, fileUploadFactory: operationsProvider, storage: storage, sessionVault: sessionVault, moc: moc)
        subscribeToPhotoUploads(isAvailable: photoUploadAvailabilityController.isAvailable, photos: photosRepository.photos)
    }

    func subscribeToPhotoUploads(isAvailable: AnyPublisher<Bool, Never>, photos: AnyPublisher<[Photo], Never>) {

        let isAvailableRegulator = isAvailable
            .handleEvents(receiveOutput: { [weak self] isAvailable in
                if !isAvailable {
                    self?.stop()
                }
            })
            .filter { $0 }
            .eraseToAnyPublisher()
        
        let nonEmptyPhotos = photos
            .filter { !$0.isEmpty }

        cancellable = isAvailableRegulator
            .flatMap { _ in nonEmptyPhotos }
            .throttle(for: throttle, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.uploadPhotos($0) }
    }
    
    private func uploadPhotos(_ photos: [Photo]) {
        for photo in photos {
            self.moc.perform { [weak self] in
                guard let self else { return }
                guard self.canUploadPhoto(photo) else { return }
                self.upload(photo, completion: { _ in })
            }
        }
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
