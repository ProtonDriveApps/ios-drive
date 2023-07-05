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
    var result: AnyPublisher<URL, Error> { get }
    func execute(with id: NodeIdentifier)
}

final class DecryptedFileContentResource: FileContentResource {
    private let storage: StorageManager
    private let downloader: Downloader
    private let fetchResource: FileFetchResource
    private let subject = PassthroughSubject<URL, Error>()
    private var ids = [NodeIdentifier]()
    private var task: Task<Void, Never>?

    var result: AnyPublisher<URL, Error> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(storage: StorageManager, downloader: Downloader, fetchResource: FileFetchResource) {
        self.downloader = downloader
        self.storage = storage
        self.fetchResource = fetchResource
    }

    deinit {
        task?.cancel()
        downloader.cancel(operationsOf: ids)
    }

    func execute(with id: NodeIdentifier) {
        ids.append(id)
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

    private func executeInBackground(id: NodeIdentifier) async {
        do {
            let file = try await loadFile(with: id)
            let url = try loadDecryptedURL(from: file)
            await finish(with: url)
        } catch {
            await finish(with: error)
        }
    }

    private func loadFile(with id: NodeIdentifier) async throws -> File {
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

    private func fetchFile(with id: NodeIdentifier) throws -> File {
        return try fetchResource.fetchFile(with: id, context: storage.backgroundContext)
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
}
