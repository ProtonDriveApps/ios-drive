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
    private let processor: PhotoFeederPreprocessorProtocol
    private let feedSubject: PassthroughSubject<Void, Never>

    private let uploader: PhotoUploader
    private let sdkPhotoUploaderBlock: () -> SDKFileUploaderProtocol?
    private let shouldFeedPublisher: AnyPublisher<Bool, Never>
    private var uploadPendingPhotosSubscription: AnyCancellable?
    @ThreadSafe private var isFeederAvailable = true

    private var sdkPhotoUploader: SDKFileUploaderProtocol? {
        sdkPhotoUploaderBlock()
    }

    public init(
        uploader: PhotoUploader,
        sdkPhotoUploaderBlock: @escaping () -> SDKFileUploaderProtocol?,
        notificationCenter: NotificationCenter,
        isBackupAvailable: AnyPublisher<Bool, Never>,
        shouldFeedPublisher: AnyPublisher<Bool, Never>,
        processor: PhotoFeederPreprocessorProtocol,
        feedSubject: PassthroughSubject<Void, Never>
    ) {
        self.uploader = uploader
        self.sdkPhotoUploaderBlock = sdkPhotoUploaderBlock
        self.notificationCenter = notificationCenter
        self.shouldFeedPublisher = shouldFeedPublisher
        self.processor = processor
        self.feedSubject = feedSubject

        /// Is backup available (is enabled and has no constraints - `LocalPhotosBackupUploadAvailableController`)
        isBackupAvailable
            .removeDuplicates()
            .receive(on: queue)
            .sink { [weak self] isAvailable in
                guard let self else { return }
                Log.info("📸📀 Backup is enabled: \(isAvailable)", domain: .uploader)
                self.isFeederAvailable = isAvailable

                if isAvailable {
                    self.subscribeToQueuedUploads()
                    self.processPendingPhotos()
                } else {
                    self.processor.suspend()
                    self.uploadPendingPhotosSubscription?.cancel()
                    self.uploadPendingPhotosSubscription = nil
                    self.uploader.onUploadsDisabled()
                    Task { @MainActor in
                        await self.sdkPhotoUploader?.pauseAll()
                    }
                }
            }.store(in: &cancellables)

        // Is the app running in the foreground, unlocked... etc
        // ConcreteComputationalAvailabilityController
        shouldFeedPublisher
            .sink {  [weak self] shouldFeed in
                guard let self else { return }
                if shouldFeed {
                    Log.info("📸🥣✅ resume all operations", domain: .uploader)
                    self.uploader.queue.isSuspended = false
                    Task {
                        await self.resumePausedSDKUploads()
                    }
                } else {
                    Log.info("📸🥣❌ pause all operations", domain: .uploader)
                    self.uploader.queue.isSuspended = true
                    Task { @MainActor in
                        await self.sdkPhotoUploader?.pauseAll()
                    }
                }
            }.store(in: &cancellables)
    }

    @MainActor
    private func resumePausedSDKUploads() async {
        guard let sdkPhotoUploader else {
            return
        }
        // Resume pending operations
        await sdkPhotoUploader.resumePausedUploads()
        // Invoke feeder to add more to queue if necessary
        notificationCenter.post(name: .uploadPendingPhotos)
    }

    func subscribeToQueuedUploads() {
        /// Fire when a photo is uploaded or a photo is imported
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
        guard isFeederAvailable else {
            Log.info("📸☁️ No need to feed photos, we don't have a feed available.", domain: .uploader)
            return
        }
        feedSubject.send()
    }
}
