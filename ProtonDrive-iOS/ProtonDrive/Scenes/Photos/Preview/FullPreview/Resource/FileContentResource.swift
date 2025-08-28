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
import PDCore

protocol FileContentResource {
    var result: AnyPublisher<FileContent, Error> { get }
    func execute(with id: any VolumeIdentifiable)
    func cancel()
}

enum FileContentResourceError: Error {
    case cancelled
    case missingDecryptedURL
}

struct FileContent {
    let url: URL
    let childrenURLs: [URL]
    let couldBeLivePhoto: Bool
    let couldBeBurst: Bool
    /// `True` indicates that some of the child content is still unavailable, possibly due to downloading or uploading.
    var isLoading: Bool
}

final class DecryptedPhotoContentResource: FileContentResource {
    private let fetchResource: PhotoFetchResourceProtocol
    private let photoUploadedNotifier: PhotoUploadedNotifier
    private let managedObjectContext: NSManagedObjectContext
    private let subject = PassthroughSubject<FileContent, Error>()
    private var id: (any VolumeIdentifiable)?
    private var task: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let photoDecryptor: any FileContentDecryptor<Photo>
    private let photoDownloader: any FileContentDownloader<Photo>
    private let contentLoadStrategy: PhotoContentLoadStrategyProtocol
    private var lastFileContent: FileContent?

    var result: AnyPublisher<FileContent, Error> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(
        managedObjectContext: NSManagedObjectContext,
        downloader: Downloader,
        fetchResource: PhotoFetchResourceProtocol,
        validationResource: FileURLValidationResource,
        photoUploadedNotifier: PhotoUploadedNotifier
    ) {
        self.fetchResource = fetchResource
        self.managedObjectContext = managedObjectContext
        self.photoUploadedNotifier = photoUploadedNotifier
        self.photoDecryptor = RemoteFileContentDecryptor<Photo>(validator: validationResource)
        self.photoDownloader = RemoteFileContentDownloader<Photo>(managedObjectContext: managedObjectContext, downloader: downloader)
        self.contentLoadStrategy = PhotoContentLoadStrategy(fetchResource: fetchResource, managedObjectContext: managedObjectContext)
    }

    deinit {
        cancel()
    }

    func execute(with id: any VolumeIdentifiable) {
        guard self.id?.any() != id.any() else { return }
        cancel()
        self.id = id
        task = Task(priority: .userInitiated) { [weak self] in
            self?.photoDownloader.set(id: id)
            await self?.executeInBackground(id: id)
        }
    }

    func cancel() {
        task?.cancel()
        lastFileContent = nil
        photoDownloader.cancel()
        id = nil
    }

    @MainActor
    private func finish(with content: FileContent) {
        lastFileContent = content
        subject.send(content)
    }

    @MainActor
    private func finish(with error: Error) {
        subject.send(completion: .failure(error))
    }
}

extension DecryptedPhotoContentResource {
    private func executeInBackground(id: any VolumeIdentifiable) async {
        do {
            let strategy = try contentLoadStrategy.loadStrategy(of: id)
            let mainPhoto = try fetchResource.fetchPhoto(with: id, context: managedObjectContext)
            switch strategy {
            case .waitingForMainAssetUploaded:
                subscribeForUpdate(id: id)
            case .returnMainAssetDuringChildrenUpload:
                subscribeForUpdate(id: id)
                try await preparePhotoContent(mainPhoto: mainPhoto, children: [], isLoading: true)
            case .returnMainAssetAndDownloadChildren:
                cancellables.removeAll()
                try await preparePhotoContent(mainPhoto: mainPhoto, children: [], isLoading: true)

                let children = getChildren(from: mainPhoto)
                try await preparePhotoContent(mainPhoto: mainPhoto, children: children, isLoading: false)
            case .allAssetsAvailable:
                cancellables.removeAll()
                let children = getChildren(from: mainPhoto)
                try await preparePhotoContent(mainPhoto: mainPhoto, children: children, isLoading: false)
            }
        } catch {
            await finishWithDetailedError(error: error, id: id)
        }
    }

    private func finishWithDetailedError(error: Error, id: any VolumeIdentifiable) async {
        if let validationError = error as? FileURLValidationResourceError {
            switch validationError {
            case .unsupportedPhoto:
                await finish(with: FileContentError.unsupportedPhoto)
            case .unsupportedVideo:
                await finish(with: FileContentError.unsupportedVideo)
            }
        } else {
            let isVideo = managedObjectContext.performAndWait {
                (try? fetchResource.fetchPhoto(with: id, context: managedObjectContext))?.isVideo
            } ?? false
            if isVideo {
                await finish(with: FileContentError.failedVideo)
            } else {
                await finish(with: FileContentError.failedPhoto)
            }
        }
    }

    private func subscribeForUpdate(id: any VolumeIdentifiable) {
        guard cancellables.isEmpty else { return }
        photoUploadedNotifier.uploadedNotifier
            .sink(receiveValue: { [weak self] nodeID in
                guard nodeID == id.id else { return }
                self?.task = Task(priority: .userInitiated) { [weak self] in
                    await self?.executeInBackground(id: id)
                }
            })
            .store(in: &cancellables)
    }
    
    private func getChildren(from mainPhoto: Photo) -> [Photo] {
        managedObjectContext.performAndWait {
            Array(mainPhoto.nonDuplicatedChildren)
        }
    }
    
    private func preparePhotoContent(
        mainPhoto: Photo,
        children: [Photo],
        isLoading: Bool
    ) async throws {
        let photos = isLoading ? [mainPhoto] : [mainPhoto] + children
        
        try await photoDownloader.downloadIfNotCached(files: photos)
        let mainPhotoURL: URL
        if let lastFileContent {
            // Don't need to decrypt main photo again
            mainPhotoURL = lastFileContent.url
        } else {
            let (_, url) = try await photoDecryptor.loadAndValidateDecryptedURL(from: mainPhoto)
            mainPhotoURL = url
        }

        let children = isLoading ? [] : children
        let decryptedResult = try await photoDecryptor.loadAndValidateDecryptedURL(from: children)
        let childrenURLs: [URL] = Array(decryptedResult.values)

        let content = FileContent(
            url: mainPhotoURL,
            childrenURLs: childrenURLs,
            couldBeLivePhoto: mainPhoto.canBeLivePhoto,
            couldBeBurst: mainPhoto.canBeBurstPhoto,
            isLoading: isLoading
        )
        await finish(with: content)
    }
}
