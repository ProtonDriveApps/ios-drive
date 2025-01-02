// Copyright (c) 2024 Proton AG
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

import CoreData
import Combine
import Foundation
import PDCore

/// Download the remote content asynchronously.
protocol FileContentDownloader<FileType> {
    associatedtype FileType
    
    func set(id: NodeIdentifier?)
    func cancel()
    
    @discardableResult
    func downloadIfNotCached(files: [FileType]) async throws -> [FileType]
}

final class RemoteFileContentDownloader<T: File>: FileContentDownloader {
    typealias FileType = T
    private let downloader: Downloader
    private let managedObjectContext: NSManagedObjectContext
    private var capturedContinuations: [NodeIdentifier: CheckedContinuation<T, any Error>] = [:]
    private var id: NodeIdentifier?
    
    init(managedObjectContext: NSManagedObjectContext, downloader: Downloader) {
        self.managedObjectContext = managedObjectContext
        self.downloader = downloader
    }
    
    func set(id: NodeIdentifier?) {
        self.id = id
    }
    
    func cancel() {
        capturedContinuations.values.forEach { $0.resume(throwing: FileContentResourceError.cancelled) }
        capturedContinuations = [:]
        if let id {
            downloader.cancel(operationsOf: [id])
        }
        self.id = nil
    }
    
    @discardableResult
    func downloadIfNotCached(files: [FileType]) async throws -> [FileType] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for file in files {
                group.addTask {
                    try await self.download(file: file)
                }
            }
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    private func download(file: FileType) async throws -> FileType {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            if self?.isCached(file: file) ?? false {
                continuation.resume(returning: file)
                return
            }
            self?.managedObjectContext.perform {
                self?.capturedContinuations[file.identifier] = continuation
                self?.downloader.scheduleDownloadWithBackgroundSupport(cypherdataFor: file) { result in
                    guard let continuation = self?.capturedContinuations[file.identifier] else {
                        return
                    }
                    self?.capturedContinuations[file.identifier] = nil
                    switch result {
                    case .success:
                        // To ensure the object is within the same context,
                        // return the file instead of the object associated with .success
                        continuation.resume(returning: file)
                    case .failure(let failure):
                        continuation.resume(throwing: failure)
                    }
                }
            }
        }
    }
    
    private func isCached(file: FileType) -> Bool {
        return file.moc?.performAndWait {
            file.activeRevision?.blocksAreValid()
        } ?? false
    }
}
