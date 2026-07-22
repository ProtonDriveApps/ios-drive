// Copyright (c) 2025 Proton AG
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

#if os(iOS)

import CoreData
import PDClient
import Combine
#if canImport(UIKit)
import UIKit
#endif
import ProtonCoreUtilities

public final class SDKOfflineSaver: BaseOfflineSaver, OfflineSaverProtocol {
    typealias IdentifiersSet = Set<AnyVolumeIdentifier>
    private weak var storage: StorageManager?
    private weak var downloader: Downloader?
    private let sdkDownloader: SDKFileDownloaderProtocol
    private let connectionStateResource: ConnectionStateResource

    private lazy var managedObjectContext: NSManagedObjectContext? = {
        // Having a lot of AO files creates a bottleneck due to scanning and rechecking filesystem consistency
        // Better to have a separate context for offline saver
        storage?.newBackgroundContext()
    }()

    private var appStateCancellables: Set<AnyCancellable> = []
    private var filesUpdatesCancellables: Set<AnyCancellable> = []
    @MainActor private var markedIdentifiers = IdentifiersSet()
    @MainActor private var finishedIdentifiers = IdentifiersSet()
    private var stateSubject = CurrentValueSubject<OfflineSaverState, Never>(.inactive)
    private let processingQueue = OperationQueue(maxConcurrentOperation: 1, isSuspended: false, name: "SDKOfflineSaver.processingQueue") // serial queue
    private let downloadsQueue = OperationQueue(maxConcurrentOperation: 2, isSuspended: false, name: "SDKOfflineSaver.downloadsQueue") // 2 downloads at a time

    private lazy var databaseResource: OfflineSaverDatabaseResource = {
        OfflineSaverDatabaseResource(storageManager: storage!, managedObjectContext: managedObjectContext!, configuration: configuration, downloader: downloader!)
    }()

    // MARK: Constraints

    private enum Constraints {
        case inactive
        case network
        case background
    }

    private var constraints: Set<Constraints> = [.inactive]

    // MARK: Public variables

    public var state: AnyPublisher<OfflineSaverState, Never> {
        stateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public init(
        configuration: OfflineSaverConfiguration,
        storage: StorageManager,
        downloader: Downloader,
        sdkDownloader: SDKFileDownloaderProtocol,
        connectionStateResource: ConnectionStateResource,
        cleanUpController: CleanUpEventController
    ) {
        self.storage = storage
        self.downloader = downloader
        self.sdkDownloader = sdkDownloader
        self.connectionStateResource = connectionStateResource

        super.init(configuration: configuration)

        subscribeToAppStateUpdates()
    }

    // MARK: - Public

    public func start() {
        Log.info("Making saver active", domain: .offlineAvailable)
        constraints.remove(.inactive)
        resumeIfPossible()
    }

    public func cleanUp() {
        Log.info("Making saver inactive", domain: .offlineAvailable)
        constraints.insert(.inactive)
        stopOperations()
    }

    // MARK: - Private state changes

    private func stopOperations() {
        Log.info("Pausing operations", domain: .offlineAvailable)
        filesUpdatesCancellables.removeAll()
        Task {
            let pendingIdentifiers = await markedIdentifiers.subtracting(finishedIdentifiers)
            sdkDownloader.cancel(operationsOf: Array(pendingIdentifiers))
        }
        databaseResource.stop()
    }

    private func resumeIfPossible() {
        guard constraints.isEmpty else {
            return
        }

        Log.info("Resuming operations", domain: .offlineAvailable)
        Task { @MainActor in
            markedIdentifiers.removeAll()
            finishedIdentifiers.removeAll()
        }
        subscribeToFilesUpdates()
        databaseResource.start()
    }

    // MARK: - Subscriptions

    private func subscribeToAppStateUpdates() {
        connectionStateResource.state
            .sink { [weak self] state in
                self?.handleNetwork(state: state)
            }
            .store(in: &appStateCancellables)

        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main) // buy sometime for Downloader to update
            .sink { [weak self] _ in
                self?.handleAppTransition(isInForeground: true)
            }
            .store(in: &appStateCancellables)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppTransition(isInForeground: false)
            }
            .store(in: &appStateCancellables)
        #endif
    }

    private func subscribeToFilesUpdates() {
        databaseResource.added
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] added in
                Task { @MainActor in
                    self?.updateDownloadable(added)
                }
            }
            .store(in: &filesUpdatesCancellables)

        databaseResource.cancelled
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] cancelled in
                Task { @MainActor in
                    self?.updateCancellable(cancelled)
                }
            }
            .store(in: &filesUpdatesCancellables)
    }

    private func handleNetwork(state: NetworkState) {
        switch state {
        case .reachable:
            constraints.remove(.network)
            resumeIfPossible()
        case .unreachable:
            constraints.insert(.network)
            stopOperations()
        }
    }

    private func handleAppTransition(isInForeground: Bool) {
        if isInForeground {
            constraints.remove(.background)
            resumeIfPossible()
        } else {
            constraints.insert(.background)
            stopOperations()
        }
    }

    @MainActor
    private func updateDownloadable(_ identifiers: Set<AnyVolumeIdentifier>) {
        let downloadableIdentifiers = identifiers.subtracting(markedIdentifiers)
        markedIdentifiers.formUnion(downloadableIdentifiers)
        downloadableIdentifiers.forEach(scheduleDownload)
        updateProgress()
    }

    @MainActor
    private func updateCancellable(_ identifiers: Set<AnyVolumeIdentifier>) {
        markedIdentifiers.subtract(identifiers)
        finishedIdentifiers.subtract(identifiers) // We don't account for them in global progress anymore
        Task.detached { [weak self] in
            self?.sdkDownloader.cancel(operationsOf: Array(identifiers))
        }
        updateProgress()
    }

    // MARK: Downloads & progresses

    private func scheduleDownload(identifier: AnyVolumeIdentifier) {
        let operation = AsynchronousBlockOperation { [weak self] in
            await self?.download(identifier: identifier)
        }
        downloadsQueue.addOperation(operation)
    }

    private func download(identifier: AnyVolumeIdentifier) async {
        guard await markedIdentifiers.contains(identifier), constraints.isEmpty else {
            return
        }
        Log.debug("Using SDK downloader for offline available: \(identifier.id)", domain: .offlineAvailable)
        do {
            try await sdkDownloader.download(file: identifier, options: [.saveAsOfflineAvailable])
            Log.info("File downloaded as offline available: \(identifier.id)", domain: .offlineAvailable)
            try relocateThumbnail(identifier: identifier)
            await MainActor.run {
                finishedIdentifiers.insert(identifier)
                updateProgress()
            }
        } catch SDKDownloadErrors.cancelled {
            Log.debug("Cancelled download for \(identifier.id)", domain: .offlineAvailable)
        } catch {
            // There's no retry here. Relaunch of offline available scanning (or the app) would be needed to repair this.
            Log.error("Failed to make offline available \(identifier.id)", error: error, domain: .offlineAvailable)
        }
    }

    @MainActor
    private func updateProgress() {
        Log.debug("UpdateProgress, \(finishedIdentifiers.count) out of \(markedIdentifiers.count)", domain: .offlineAvailable)

        guard !markedIdentifiers.isEmpty else {
            stateSubject.send(.inactive)
            return
        }

        let fraction = Double(finishedIdentifiers.count) / Double(markedIdentifiers.count)
        stateSubject.send(.progress(fraction))

        // Can reset the identifiers when all currently marked files are downloaded
        if markedIdentifiers.isSubset(of: finishedIdentifiers) {
            Log.debug("Cleaning up processed available offline ids to reset progress", domain: .offlineAvailable)
            let completedBatch = finishedIdentifiers
            markedIdentifiers.removeAll()
            finishedIdentifiers.removeAll()
            databaseResource.markBatchFinished(completedBatch)
        }
    }
    
    private func relocateThumbnail(identifier: AnyVolumeIdentifier) throws {
        #if os(iOS)
        for type in ThumbnailType.allCases {
            guard
                let tempURL = PDFileManager.thumbnailURL(
                    for: identifier.volumeBasedIdentifier,
                    type: type,
                    preferStorageType: .temporary
                ),
                FileManager.default.fileExists(atPath: tempURL.path)
            else { continue }
            let permanentURL = PDFileManager.createThumbnailURL(for: identifier.volumeBasedIdentifier, type: type, storageType: .permanent)
            try FileManager.default.moveItem(at: tempURL, to: permanentURL)
        }
        #endif
    }
}

#endif
