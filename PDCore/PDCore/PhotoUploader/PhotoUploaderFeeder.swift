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

import Combine
import Foundation

public final class PhotoUploaderFeeder {
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "PhotoUploaderFeeder", qos: .background)
    private let notificationCenter: NotificationCenter

    private let uploader: PhotoUploader
    private let uploadingPhotosRepository: UploadingPrimaryPhotosRepository
    private let shouldFeedPublisher: AnyPublisher<Bool, Never>
    private var uploadPendingPhotosSubscription: AnyCancellable?

    public init(
        uploader: PhotoUploader,
        uploadingPhotosRepository: UploadingPrimaryPhotosRepository,
        notificationCenter: NotificationCenter,
        isBackupAvailable: AnyPublisher<Bool, Never>,
        newPhotoAvailable: AnyPublisher<[Photo], Never>,
        shouldFeedPublisher: AnyPublisher<Bool, Never>
    ) {
        self.uploader = uploader
        self.uploadingPhotosRepository = uploadingPhotosRepository
        self.notificationCenter = notificationCenter
        self.shouldFeedPublisher = shouldFeedPublisher

        isBackupAvailable
            .removeDuplicates()
            .receive(on: queue)
            .sink { [weak self] isAvailable in
                guard let self else { return }
                Log.info("📸📀 Backup is enabled: \(isAvailable)", domain: .uploader)
                self.uploader.isEnabled = isAvailable

                if isAvailable {
                    self.subscribeToQueuedUploads()
                    self.processPendingPhotos()
                } else {
                    self.uploadPendingPhotosSubscription?.cancel()
                    self.uploadPendingPhotosSubscription = nil
                    self.uploader.onUploadsDisabled()
                }
            }.store(in: &cancellables)

        shouldFeedPublisher
            .sink {  [weak self] shouldFeed in
                guard let self else { return }
                if shouldFeed {
                    Log.info("📸🥣✅ resume all operations", domain: .uploader)
                    self.uploader.queue.isSuspended = false
                    notificationCenter.post(name: .uploadPendingPhotos)
                } else {
                    Log.info("📸🥣❌ pause all operations", domain: .uploader)
                    self.uploader.queue.isSuspended = true
                }
            }.store(in: &cancellables)
    }

    func subscribeToQueuedUploads() {
        let continueUploadPublisher = notificationCenter.getPublisher(for: .uploadPendingPhotos, publishing: Void.self).eraseToAnyPublisher()
        let feedingPublisher = shouldFeedPublisher.filter { $0 }.map { _ in Void() }
            .handleEvents(receiveOutput: {
                Log.info("App will start feeding 📸", domain: .uploader)
            })
            .eraseToAnyPublisher()
        uploadPendingPhotosSubscription = continueUploadPublisher.merge(with: feedingPublisher)
            .collect(.byTimeOrCount(queue, .seconds(2), 20))
            .sink { [weak self] _ in
                guard let self else { return }
                Log.info("📸☁️ Will determine how many photos do we have.", domain: .uploader)
                self.processPendingPhotos()
            }
    }

    private func processPendingPhotos() {
        let processingPhotos = uploader.getExecutableOperationsCount()

        if  processingPhotos < Constants.processingPhotoUploadsBatchSize / 2 {
            let photos = self.uploadingPhotosRepository.getPhotos()
            Log.info("📸☁️✅ Photo upload scheduled willAdd: \(photos.count) Total: \(photos.count + processingPhotos)", domain: .uploader)
            self.uploader.upload(files: photos)
        } else {
            Log.info("📸☁️⚠️ Photo upload  currently \(processingPhotos) photos in queue", domain: .uploader)
        }
    }
}
