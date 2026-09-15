// Copyright (c) 2026 Proton AG
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
import CoreData
import Foundation
import PDCore
import PDCoreIOS
import PDSDKCore
import PDSDKCoreiOS
import ProtonCoreNetworking

@MainActor
protocol FinderTransferManaging {
    func startMonitor()

    func pauseUpload(id: AnyVolumeIdentifier) async
    func cancelUpload(id: AnyVolumeIdentifier) async
    func uploadFile(_ content: URLContent, to folder: NodeDTO) async throws
    func restartUpload(id: AnyVolumeIdentifier) async

    func download(node: AnyVolumeIdentifier) async throws
}

/// Manages file uploads, downloads, and progress reporting
/// Progress updates are provided through `ProgressTrackersController`
@MainActor
final class FinderTransferManager: FinderTransferManaging {
    private let childrenUploadingObserver: FetchedObjectsObserver<CoreDataFile>
    private let progressTrackersController: ProgressTrackersControllerProtocol
    private let tower: Tower
    private let context: NSManagedObjectContext
    private let userMessageHandler: UserMessageHandlerProtocol
    private var downloadCancellable: AnyCancellable?
    private var uploadCancellable: AnyCancellable?
    private var hasStarted = false

    init(
        progressTrackersController: ProgressTrackersControllerProtocol,
        tower: Tower,
        userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
    ) {
        self.progressTrackersController = progressTrackersController
        self.tower = tower
        let pool = tower.storage.synchronousContextPool
        let context = pool.acquire()
        self.context = context
        let uploads = tower.storage.subscriptionToUploadingFiles(preferredContext: context)
        self.childrenUploadingObserver = FetchedObjectsObserver(uploads, onDeinit: {
            pool.relinquish(context)
        })
        self.userMessageHandler = userMessageHandler
    }

    func startMonitor() {
        if hasStarted { return }
        hasStarted = true
        subscribeToChildrenDownloading()
        subscribeToChildrenUploading()
        Task.detached {
            await self.childrenUploadingObserver.start()
        }
    }
}

// MARK: - Upload
extension FinderTransferManager {
    private func subscribeToChildrenUploading() {
        uploadCancellable?.cancel()
        uploadCancellable = childrenUploading()
            .catch {  [weak self] error -> Empty<([CoreDataFile], [UUID: Progress]), Error> in
                return .init()
            }
            .sink(receiveCompletion: { [weak self] _ in
                self?.subscribeToChildrenUploading()
            }, receiveValue: { [weak self] files, progress in
                let trackersValues = progress.map { key, value in
                    return (key.uuidString, ProgressTracker(progress: value, direction: .upstream))
                }
                let trackersDictionary = Dictionary(uniqueKeysWithValues: trackersValues)
                self?.progressTrackersController.setUploads(progresses: trackersDictionary)
            })
    }

    private func childrenUploading() -> AnyPublisher<([CoreDataFile], [UUID: Progress]), Error> {
        return childrenUploadingObserver.objectWillChange
            .setFailureType(to: Error.self)
            .combineLatest(sdkProgressPublisher())
            .throttle(for: 0.02, scheduler: DispatchQueue.main, latest: true)
            .map { [weak self] (_, sdkProgresses) in
                guard let self else { return ([], sdkProgresses) }
                return (self.childrenUploadingObserver.fetchedObjects, sdkProgresses)
            }
            .removeDuplicates(by: { previous, current in
                return previous.0 == current.0 && previous.1 == current.1
            })
            .eraseToAnyPublisher()
    }

    private func sdkProgressPublisher() -> AnyPublisher<[UUID: Progress], Error> {
        let sdkFileUploader = tower.sdkObjects.fileUploader
        return sdkFileUploader.progresses
            .setFailureType(to: Error.self)
            .merge(
                with: sdkFileUploader.failures
                    .flatMap { _ in Empty<[UUID: Progress], Error>() }
            )
            .eraseToAnyPublisher()
    }

    func pauseUpload(id: AnyVolumeIdentifier) async {
        await tower.sdkObjects.fileUploader.pause(identifier: id)
    }

    func cancelUpload(id: AnyVolumeIdentifier) async {
        let sdkUploader = tower.sdkObjects.fileUploader
        do {
            try await sdkUploader.deleteUploadingFile(identifier: id)
        } catch {
            Log.error("Cancel upload \(id.debugDesc) failed", error: error, domain: .uploader)
        }
    }

    func uploadFile(_ content: URLContent, to folder: NodeDTO) async throws {
        let parent: CoreDataFolder = try await context.perform { [context] in
            try context.typedObject(with: folder.objectID)
        }
        let newFile = try tower.fileImporter.importFile(from: content.url, to: parent, with: nil)
        guard content.size == content.url.fileSize else {
            assert(false, "Failed to create File")
            throw URLConsistencyError.urlSizeMismatch
        }
        let fileUploader = tower.sdkObjects.fileUploader
        // The error will be handled by `uploader.failures`
        _ = try? await fileUploader.upload(identifier: newFile.genericIdentifier)
    }

    func restartUpload(id: AnyVolumeIdentifier) async {
        let fileUploader = tower.sdkObjects.fileUploader
        do {
            // Should resume if paused, otherwise starts from scratch
            _ = try await fileUploader.upload(identifier: id)
        } catch {
            if let uploadError = error as? SDKUploadErrors, uploadError == .cancelled { return }
            Log.error("Resume upload \(id.debugDesc) failed", error: error, domain: .uploader)
        }
    }
}

// MARK: - Download
extension FinderTransferManager {
    private func subscribeToChildrenDownloading() {
        downloadCancellable?.cancel()
        downloadCancellable = childrenDownloading()
            .receive(on: DispatchQueue.main)
            .catch { [weak self] error -> Empty<ProgressTrackers, Error> in
                let error: Error = (error as? ResponseError)?.underlyingError ?? error
                self?.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
                return .init()
            }
            .sink(receiveCompletion: { [weak self] _ in
                self?.subscribeToChildrenDownloading()
            }, receiveValue: { [weak self] progresses in
                // This only sets data to controller so only relevant subviews can subscribe and reload
                self?.progressTrackersController.setDownloads(progresses: progresses)
            })
    }

    private func childrenDownloading() -> AnyPublisher<ProgressTrackers, Error> {
        let downloader = tower.sdkObjects.fileDownloader
        let sdkPublisher = makeSDKProgresses(sdkDownloader: downloader)
        return sdkPublisher
            .mapError { $0 }
            .eraseToAnyPublisher()
    }

    private func makeSDKProgresses(sdkDownloader: SDKFileDownloaderProtocol) -> AnyPublisher<ProgressTrackers, Error> {
        let failurePublisher = sdkDownloader.failures
            .first() // only care about the first emission
            .flatMap { value in
                Fail<ProgressTrackers, Error>(error: value.1)
            }
            .eraseToAnyPublisher()
        let combinedPublisher = sdkDownloader.progresses
            .map { progresses in
                let keysAndValues = progresses.map { progressEntry in
                    let progress = progressEntry.value
                    progress.fileURL = URL(string: progressEntry.key.id) // This is necessary to `match` progresses against files
                    return (progressEntry.key.id, ProgressTracker(progress: progress, direction: .downstream))
                }
                return Dictionary(uniqueKeysWithValues: keysAndValues)
            }
            .setFailureType(to: Error.self)
            .merge(with: failurePublisher)
        return combinedPublisher.eraseToAnyPublisher()
    }

    func download(node: AnyVolumeIdentifier) async throws {
        try await tower.sdkObjects.fileDownloader.download(file: node)
    }
}
