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
import PDCore

protocol FileContentResource {
    var result: AnyPublisher<URL, Error> { get }
    func execute(with id: PhotoId)
}

final class DecryptedFileContentResource: FileContentResource {
    private let storage: StorageManager
    private let downloader: Downloader
    private let subject = PassthroughSubject<URL, Error>()
    private var task: Task<Void, Never>?

    var result: AnyPublisher<URL, Error> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(storage: StorageManager, downloader: Downloader) {
        self.downloader = downloader
        self.storage = storage
    }

    deinit {
        task?.cancel()
    }

    func execute(with id: PhotoId) {
        task = Task { [weak self] in
            await self?.executeInBackground(id: id)
        }
    }

    @MainActor
    private func finish(with url: URL) {
        subject.send(url)
    }

    @MainActor
    private func finish(with error: Error) {
        subject.send(completion: .failure(error))
    }

    private func executeInBackground(id: PhotoId) async {
        do {
            let file = try await loadFile(with: id)
            let url = try loadDecryptedURL(from: file)
            await finish(with: url)
        } catch {
            await finish(with: error)
        }
    }

    private func loadFile(with id: PhotoId) async throws -> File {
        let file = try fetchFile(with: id)
        if isCached(file: file) {
            return file
        } else {
            return try await download(file: file)
        }
    }

    private func isCached(file: File) -> Bool {
        return file.moc?.performAndWait {
            file.activeRevision?.blocksAreValid()
        } ?? false
    }

    private func fetchFile(with id: PhotoId) throws -> File {
        let context = storage.backgroundContext
        return try storage.fetchPhoto(id: id, moc: context)
    }

    private func download(file: File) async throws -> File {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.storage.backgroundContext.perform {
                self?.downloader.scheduleDownloadWithBackgroundSupport(cypherdataFor: file) { result in
                    switch result {
                    case let .success(file):
                        continuation.resume(returning: file)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func loadDecryptedURL(from file: File) throws -> URL {
        guard let revision = file.activeRevision else {
            throw Revision.noMOC()
        }
        return try revision.decryptFile()
    }
}
