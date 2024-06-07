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
    private let synchronousRepository: SynchronousThumbnailRepository
    private let asynchronousRepository: AsynchronousThumbnailRepository
    private let id: PhotoId
    private var cancellables = Set<AnyCancellable>()
    private var subject = PassthroughSubject<Void, Never>()
    private var isFailedSubject = CurrentValueSubject<Bool, Never>(false)

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var isFailed: AnyPublisher<Bool, Never> {
        isFailedSubject.eraseToAnyPublisher()
    }

    init(thumbnailsController: ThumbnailsController, urlsController: ThumbnailURLsController, synchronousRepository: SynchronousThumbnailRepository, asynchronousRepository: AsynchronousThumbnailRepository, id: PhotoId) {
        self.thumbnailsController = thumbnailsController
        self.urlsController = urlsController
        self.synchronousRepository = synchronousRepository
        self.asynchronousRepository = asynchronousRepository
        self.id = id
    }

    func bootstrap() {
        cancel()
        thumbnailsController.readyIds
            .map { [weak self] ids in
                guard let self = self else { return false }
                return ids.contains(self.id)
            }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.handleIsReady()
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
        if synchronousRepository.load(with: id) == nil {
            asynchronousRepository.load(id: id)
        }
    }

    func cancel() {
        cancellables.removeAll()
        thumbnailsController.cancel(id)
        urlsController.cancel(id)
    }

    // MARK: - Private

    private func handleIsReady() {
        asynchronousRepository.load(id: id)
    }

    private func handleLoadUpdate(_ result: ThumbnailLoadResult) {
        switch result {
        case let .data(data):
            /// Data is decrypted, we can store to inmemory cache and publish update
            synchronousRepository.store(image: data, id: id)
            subject.send()
        case .error:
            /// Loading failed, we can publish error to consumers
            isFailedSubject.send(true)
        case .isEncrypted:
            /// Thumbnail has metadata in DB, but binary is not downloaded nor decrypted. We need to request processing.
            Log.debug("Handle thumbnail load update: isEncrypted", domain: .thumbnails)
            thumbnailsController.load(id)
        case .isRemote:
            /// Thumbnail doesn't have download URL, need to batch download it
            Log.debug("Handle thumbnail load update: isRemote", domain: .thumbnails)
            urlsController.load(id)
        }
    }

    private func handleURLUpdate() {
        /// Once an url is made available we can start downloading the encrypted data etc.
        thumbnailsController.load(id)
    }
}
