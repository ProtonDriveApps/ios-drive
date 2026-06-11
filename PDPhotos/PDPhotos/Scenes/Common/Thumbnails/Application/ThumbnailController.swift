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
import PDCore
import PDCoreIOS

protocol ThumbnailController {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    var isFailed: AnyPublisher<Bool, Never> { get }
    func getImage() -> Data?
    func bootstrap()
    func load()
    func cancel()
}

/// Single point of starting / cancelling thumbnail data retrieval.
/// Depending on a state we need to start with one of these:
///     - no URL -> request download URL via `urlsController`
///     - URL is present, but binary data not downloaded / decrypted -> start the process via `thumbnailsController`
///     - thumbnail data is already downloaded, but is in core data storage -> `asynchronousRepository`
///     - image data is decrypted and stored in memory -> `synchronousRepository`
final class LocalThumbnailController: ThumbnailController {
    private let thumbnailsController: ThumbnailsController
    private let urlsController: ThumbnailURLsController
    private let metadataController: MetadataControllerProtocol
    private let synchronousRepository: SynchronousThumbnailRepository
    private let asynchronousRepository: AsynchronousThumbnailRepository
    private let performanceMetricsController: PerformanceMetricsControllerProtocol
    private let canUseSDK: Bool
    private let id: PhotoId
    private var cancellables = Set<AnyCancellable>()
    private var subject = PassthroughSubject<Void, Never>()
    private var isFailedSubject = CurrentValueSubject<Bool, Never>(false)
    private var isWaitingForMetadata = false
    @ThreadSafe var isBootsrtapped = false

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var isFailed: AnyPublisher<Bool, Never> {
        isFailedSubject.eraseToAnyPublisher()
    }

    init(thumbnailsController: ThumbnailsController, urlsController: ThumbnailURLsController, metadataController: MetadataControllerProtocol, synchronousRepository: SynchronousThumbnailRepository, asynchronousRepository: AsynchronousThumbnailRepository, performanceMetricsController: PerformanceMetricsControllerProtocol, canUseSDK: Bool, id: PhotoId) {
        self.thumbnailsController = thumbnailsController
        self.urlsController = urlsController
        self.metadataController = metadataController
        self.synchronousRepository = synchronousRepository
        self.asynchronousRepository = asynchronousRepository
        self.performanceMetricsController = performanceMetricsController
        self.canUseSDK = canUseSDK
        self.id = id
    }

    func bootstrap() {
        if isBootsrtapped { return }
        isBootsrtapped = true
        thumbnailsController.readyIds
            .map { [weak self] ids in
                guard let self = self else { return false }
                return ids.contains(self.id)
            }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.handleLoadUpdate(.storedInFileSystem)
            }
            .store(in: &cancellables)

        thumbnailsController.failedId
            .filter { [weak self] id in
                self?.id == id
            }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.isFailedSubject.send(true)
            }
            .store(in: &cancellables)

        urlsController.readyIds
            .map { [weak self] ids in
                guard let self = self else { return false }
                return ids.contains(self.id)
            }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.handleURLUpdate()
            }
            .store(in: &cancellables)

        metadataController.readyIDs
            .map { [weak self] ids in
                guard let self = self else { return false }
                return ids.contains(self.id)
            }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.handleMetadataUpdate()
            }
            .store(in: &cancellables)

        asynchronousRepository.result
            .sink { [weak self] result in
                self?.handleLoadUpdate(result)
            }
            .store(in: &cancellables)
    }

    func getImage() -> Data? {
        synchronousRepository.load(with: id)
    }

    func load() {
        /// Start assessing thumbnail state in DB, unless it's already stored in memory cache.
        if !synchronousRepository.hasData(with: id) {
            asynchronousRepository.load(id: id)
        } else {
            performanceMetricsController.fetchThumbnail(id: id, dataSource: .local)
        }
    }

    func cancel() {
        cancellables.removeAll()
        asynchronousRepository.cancel()
        thumbnailsController.cancel(id)
        urlsController.cancel(id)
        metadataController.cancel(identifier: id)
    }

    // MARK: - Private

    private func handleLoadUpdate(_ result: ThumbnailLoadResult) {
        switch result {
        case .storedInFileSystem:
            /// Data is decrypted in file system, we can publish update
            performanceMetricsController.fetchThumbnail(id: id, dataSource: .local)
            subject.send()
        case .encrypted:
            /// Thumbnail has metadata in DB, but binary is not downloaded nor decrypted. We need to request processing.
            /// Does not require us to invoke SDK
            Log.trace("Handle thumbnail load update: encrypted", domain: .thumbnails)
            performanceMetricsController.fetchThumbnail(id: id, dataSource: .remote)
            thumbnailsController.load(id)
        case .missingURL:
            /// Thumbnail doesn't have download URL, need to batch download it
            Log.trace("Handle thumbnail load update: missingURL, will use SDK: \(canUseSDK)", domain: .thumbnails)
            performanceMetricsController.fetchThumbnail(id: id, dataSource: .remote)

            if canUseSDK {
                // In SDK, batch loading is handled for us. ThumbnailLoader invokes SDK for us
                thumbnailsController.load(id)
            } else {
                // In legacy code, we batch load URLs
                urlsController.load(id)
            }

        case .missingMetadata:
            /// Photo's metadata is not available, need to batch fetch it
            if id.id.isEmpty {
                // Album cover could be nil
                Log.debug("Handle thumbnail load update: missingMetadata, photoID is empty", domain: .thumbnails)
                return
            }
            Log.trace("Handle thumbnail load update: missingMetadata, will use SDK: \(canUseSDK)", domain: .thumbnails)
            performanceMetricsController.fetchThumbnail(id: id, dataSource: .remote)

            if canUseSDK {
                // SDK will fetch metadata + thumbnail urls + decrypt
                thumbnailsController.load(id)
            } else {
                // We need to batch fetch metadata before proceeding
                isWaitingForMetadata = true
                metadataController.loadOpportunistically([id])
            }
        }
    }

    private func handleURLUpdate() {
        /// Once an url is made available we can start downloading the encrypted data etc.
        thumbnailsController.load(id)
    }

    private func handleMetadataUpdate() {
        // Metadata controller is shared and publishes multiple times. ThumbnailURL needs to be requested
        // only when metadata requested by this object explicitly.
        guard isWaitingForMetadata else {
            return
        }
        isWaitingForMetadata = false

        // Once we have metadata, we can enqueue urls fetching
        urlsController.load(id)
    }
}
