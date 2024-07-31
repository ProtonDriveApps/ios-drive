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
    func execute(with id: NodeIdentifier)
    func cancel()
}

enum FileContentResourceError: Error {
    case cancelled
    case missingDecryptedURL
}

struct FileContent {
    let url: URL
    let childrenURLs: [URL]
    
    /// There is no solid way to check given content is live photo or not
    /// If the childrenURLs has only one video URL
    /// The given content has chance to be a live photo
    var couldBeLivePhoto: Bool {
        guard
            childrenURLs.count == 1,
            let mainMime = MimeType(fromFileExtension: url.pathExtension),
            mainMime.isImage,
            let videoURL = childrenURLs.first,
            let mime = MimeType(fromFileExtension: videoURL.pathExtension),
            mime.isVideo
        else { return false }
        return true
    }
}

final class DecryptedFileContentResource: FileContentResource {
    private let storage: StorageManager
    private let downloader: Downloader
    private let fetchResource: FileFetchResource
    private let validationResource: FileURLValidationResource
    private let managedObjectContext: NSManagedObjectContext
    private let subject = PassthroughSubject<FileContent, Error>()
    private var id: NodeIdentifier?
    private var task: Task<Void, Never>?
    private var capturedContinuations: [NodeIdentifier: CheckedContinuation<Void, Error>] = [:]

    var result: AnyPublisher<FileContent, Error> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(storage: StorageManager, downloader: Downloader, fetchResource: FileFetchResource, validationResource: FileURLValidationResource) {
        self.downloader = downloader
        self.storage = storage
        self.fetchResource = fetchResource
        self.validationResource = validationResource
        managedObjectContext = storage.newBackgroundContext()
    }

    deinit {
        cancel()
    }

    func execute(with id: NodeIdentifier) {
        guard self.id != id else {
            return
        }
        cancel()
        self.id = id
        task = Task(priority: .userInitiated) { [weak self] in
            await self?.executeInBackground(id: id)
        }
    }

    func cancel() {
        task?.cancel()
        capturedContinuations.values.forEach { $0.resume(throwing: FileContentResourceError.cancelled) }
        capturedContinuations = [:]
        if let id {
            downloader.cancel(operationsOf: [id])
        }
        id = nil
    }

    @MainActor
    private func finish(with content: FileContent) {
        subject.send(content)
    }

    @MainActor
    private func finish(with error: Error) {
        subject.send(completion: .failure(error))
    }

    private func executeInBackground(id: NodeIdentifier) async {
        do {
            let file = try await loadFile(with: id)
            let urls = try await loadAndVerifyDecryptedURL(from: file)
            guard let mainURL = urls[file.identifier] else {
                throw FileContentResourceError.missingDecryptedURL
            }
            let childrenURLs: [URL] = urls.filter { $0.key != file.identifier }.map(\.value)
            let content = FileContent(url: mainURL, childrenURLs: childrenURLs)
            await finish(with: content)
        } catch {
            await finish(with: error)
        }
    }

    private func loadFile(with id: NodeIdentifier) async throws -> File {
        let file = try fetchFile(with: id)
        if let photo = file as? Photo {
            try await download(photo: photo)
        } else {
            if !isCached(file: file) {
                try await download(file: file)
            }
        }
        return file
    }

    private func isCached(file: File) -> Bool {
        return file.moc?.performAndWait {
            file.activeRevision?.blocksAreValid()
        } ?? false
    }

    private func fetchFile(with id: NodeIdentifier) throws -> File {
        return try fetchResource.fetchFile(with: id, context: managedObjectContext)
    }

    private func download(file: File) async throws {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.managedObjectContext.perform {
                self?.capturedContinuations[file.identifier] = continuation
                self?.downloader.scheduleDownloadWithBackgroundSupport(cypherdataFor: file) { result in
                    guard let continuation = self?.capturedContinuations[file.identifier] else {
                        return
                    }
                    self?.capturedContinuations[file.identifier] = nil
                    switch result {
                    case .success:
                        continuation.resume()
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func loadDecryptedURL(from file: File) throws -> URL {
        guard let moc = file.moc else {
            throw File.noMOC()
        }

        return try moc.performAndWait {
            guard let revision = file.activeRevision else {
                throw file.invalidState("Uploaded file should have an active revision")
            }
            return try revision.decryptFile()
        }
    }
    
    private func loadAndVerifyDecryptedURL(from file: File) async throws -> [NodeIdentifier: URL] {
        
        if let photos = getAllPhotos(from: file), !photos.isEmpty {
            return try await decryptAndVerifyPhotoURL(from: photos)
        } else {
            let url = try loadDecryptedURL(from: file)
            try await validationResource.validate(file: file, url: url)
            return [file.identifier: url]
        }
    }
}

extension DecryptedFileContentResource {
    private func getAllPhotos(from file: File) -> [Photo]? {
        guard let photo = file as? Photo else { return nil }
        return managedObjectContext.performAndWait { [photo] + Array(photo.children) }
    }

    private func download(photo: Photo) async throws {
        let photosNeedToBeDownloaded = (getAllPhotos(from: photo) ?? []).filter { !isCached(file: $0) }
        
        return try await withThrowingTaskGroup(of: Void.self) { [weak self] taskGroup in
            guard let self else { return }
            for file in photosNeedToBeDownloaded {
                taskGroup.addTask { try await self.download(file: file) }
            }
            for try await _ in taskGroup {}
        }
    }
    
    private func decryptAndVerifyPhotoURL(from photos: [Photo]) async throws -> [NodeIdentifier: URL] {
        var decryptedURL: [NodeIdentifier: URL] = [:]
        for photo in photos {
            let url = try loadDecryptedURL(from: photo)
            try await validationResource.validate(file: photo, url: url)
            decryptedURL[photo.identifier] = url
        }
        return decryptedURL
    }
}
