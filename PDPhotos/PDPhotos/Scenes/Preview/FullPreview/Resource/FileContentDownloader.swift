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
    
    func set(id: any VolumeIdentifiable)
    func cancel()
    
    @discardableResult
    func downloadIfNotCached(files: [FileType]) async throws -> [FileType]
}

final class RemoteFileContentDownloader<T: File>: FileContentDownloader {
    typealias FileType = T
    private let sdkDownloader: SDKFileDownloaderProtocol
    private let managedObjectContext: NSManagedObjectContext
    private var capturedContinuations: [AnyVolumeIdentifier: CheckedContinuation<T, any Error>] = [:]
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?
    private var id: (any VolumeIdentifiable)?

    init(
        managedObjectContext: NSManagedObjectContext,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        sdkDownloader: SDKFileDownloaderProtocol
    ) {
        self.managedObjectContext = managedObjectContext
        self.performanceMetricsController = performanceMetricsController
        self.sdkDownloader = sdkDownloader
    }
    
    func set(id: any VolumeIdentifiable) {
        self.id = id
    }
    
    func cancel() {
        capturedContinuations.values.forEach { $0.resume(throwing: FileContentResourceError.cancelled) }
        capturedContinuations = [:]
        if let id {
            sdkDownloader.cancel(operationsOf: [id.any()])
        }
        self.id = nil
    }
    
    @discardableResult
    func downloadIfNotCached(files: [FileType]) async throws -> [FileType] {
        do {
            let (mainID, cacheState) = await checkDataSource(files: files)
            reportPerformanceMetric(mainID: mainID, cacheState: cacheState)
            return try await withThrowingTaskGroup(of: T.self) { group in
                for file in files {
                    group.addTask {
                        try await self.download(file: file, cacheState: cacheState)
                    }
                }
                var results: [T] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        } catch SDKDownloadErrors.cancelled {
            throw FileContentResourceError.cancelled
        } catch {
            throw error
        }
    }
    
    private func download(file: FileType, cacheState: [String: Bool]) async throws -> FileType {
        if let hasCache = cacheState[file.genericIdentifier.id], hasCache {
            return file
        }
        
        _ = try await sdkDownloader.download(file: file.genericIdentifier)
        return file
    }

    /// - Parameter files: Files need to be downloaded
    /// - Returns: (Identifier of the main photo, [file ID: has cache])
    private func checkDataSource(files: [FileType]) async -> (AnyVolumeIdentifier, [String: Bool]) {
        guard let mainID = files.first?.genericIdentifier else { return (.init(id: "", volumeID: ""), [:]) }
        var cacheState: [String: Bool] = [:]
        let mapping = await managedObjectContext.perform {
            var mapping: [String: Revision?] = [:]
            for file in files {
                let id = file.id
                let revision = file.activeRevision
                mapping[id] = revision
            }
            return mapping
        }
        for (id, revision) in mapping {
            cacheState[id] = revision?.isAvailableLocally()
        }
        return (mainID, cacheState)
    }

    private func reportPerformanceMetric(mainID: AnyVolumeIdentifier, cacheState: [String: Bool]) {
        let allCached = cacheState.values.allSatisfy { $0 }
        performanceMetricsController?.fetchFullContent(
            id: mainID,
            dataSource: allCached ? .local : .remote
        )
    }
}
