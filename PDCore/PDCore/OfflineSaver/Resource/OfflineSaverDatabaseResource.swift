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

#if os(iOS)

import CoreData
import Combine

final class OfflineSaverDatabaseResource: NSObject, NSFetchedResultsControllerDelegate, Sendable {
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private let configuration: OfflineSaverConfiguration
    private let downloader: Downloader
    private var fetchedResultsController: NSFetchedResultsController<Node>?
    private var task: Task<Void, Error>?
    private lazy var processingQueue = OperationQueue(maxConcurrentOperation: 1, isSuspended: false, name: "\(Self.self).processingQueue")
    private lazy var notificationQueue = DispatchQueue(label: "\(Self.self).notificationQueue")
    private let addedSubject = CurrentValueSubject<Set<AnyVolumeIdentifier>, Never>([])
    private let cancelledSubject = CurrentValueSubject<Set<AnyVolumeIdentifier>, Never>([])

    var added: AnyPublisher<Set<AnyVolumeIdentifier>, Never> {
        addedSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var cancelled: AnyPublisher<Set<AnyVolumeIdentifier>, Never> {
        cancelledSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(storageManager: StorageManager, managedObjectContext: NSManagedObjectContext, configuration: OfflineSaverConfiguration, downloader: Downloader) {
        self.storageManager = storageManager
        self.managedObjectContext = managedObjectContext
        self.configuration = configuration
        self.downloader = downloader
    }

    func stop() {
        processingQueue.cancelAllOperations()
        fetchedResultsController?.delegate = nil
        fetchedResultsController = nil
    }

    func start() {
        stop()

        let operation = AsynchronousBlockOperation { [weak self] in
            self?.subscribeToUpdates()
            try? await self?.performFullScan()
        }
        processingQueue.addOperation(operation)
    }

    /// Removes fully completed batch from being notified
    func markBatchFinished(_ ids: Set<AnyVolumeIdentifier>) {
        notificationQueue.async {
            let value = self.addedSubject.value.subtracting(ids)
            self.addedSubject.send(value)
        }
    }

    private func performFullScan() async throws {
        Log.debug("Full scan 1. Starting scan of all available offline files & folders (\(configuration))", domain: .offlineAvailable)
        let foldersAndFiles = await getMarkedFoldersAndFiles()

        try Task.checkCancellation()

        Log.debug("Full scan 2. Checking marked files (\(configuration))", domain: .offlineAvailable)
        try await checkMarkedAndInheriting(files: foldersAndFiles.files)

        try Task.checkCancellation()

        Log.debug("Full scan 3. Scanning marked folders (\(configuration))", domain: .offlineAvailable)
        try await checkMarkedAndInheriting(folders: foldersAndFiles.folders)

        Log.debug("Full scan 4. Initial scan finished (\(configuration))", domain: .offlineAvailable)
    }

    private func subscribeToUpdates() {
        let fetchedResultsController = storageManager.subscriptionToOfflineAvailable(withInherited: true, moc: managedObjectContext)
        fetchedResultsController.delegate = self
        self.fetchedResultsController = fetchedResultsController

        do {
            try fetchedResultsController.performFetch()
        } catch let error {
            assertionFailure(error.localizedDescription)
            Log.error("Failed to fetch nodes marked for Offline Available", error: nil, domain: .storage)
        }
    }

    private func getMarkedFoldersAndFiles() async -> (folders: [Folder], files: [File]) {
        await managedObjectContext.perform { [weak self] in
            let folders = self?.fetchedResultsController?.sections?.first { info in
                info.indexTitle == NSNumber(value: true).stringValue
            }?.objects?.compactMap {
                $0 as? CoreDataFolder
            } ?? []

            let files = self?.fetchedResultsController?.sections?.first(where: { info in
                info.indexTitle == NSNumber(value: false).stringValue
            })?.objects?.compactMap {
                $0 as? CoreDataFile
            } ?? []

            return (folders, files)
        }
    }

    /// Check that all marked nodes are downloaded and up to date
    private func checkMarkedAndInheriting(files: [File]) async throws {
        let files = filterFiles(files: files)
        if files.isEmpty {
            return
        }

        // Already found in local cache
        let filteredFiles = try await managedObjectContext.perform { [weak self] in
            guard let self else {
                throw CancellationError()
            }
            return self.filterLocalAndRemote(files: files)
        }

        try Task.checkCancellation()

        Log.debug("Marked identifiers: \(files.count), downloaded: \(filteredFiles.downloaded.count), remote: \(filteredFiles.remote.count)", domain: .offlineAvailable)

        var remoteIdentifiers = [AnyVolumeIdentifier]()
        try await managedObjectContext.perform {
            filteredFiles.downloaded.forEach {
                self.move(file: $0, to: .offlineAvailable)
            }

            try Task.checkCancellation()

            remoteIdentifiers = filteredFiles.remote.map { $0.identifierWithinManagedObjectContext.any() }
        }

        // Notify to trigger downloads
        notifyAdded(identifiers: remoteIdentifiers)
    }

    private func filterLocalAndRemote(files: [File]) -> (downloaded: Set<File>, remote: Set<File>) {
        var downloaded = Set<File>()
        var remote = Set<File>()
        for file in files {
            guard file.isDownloadable else {
                continue
            }
            if file.activeRevision?.isAvailableLocally() == true {
                downloaded.insert(file)
            } else {
                remote.insert(file)
            }
        }
        return (downloaded, remote)
    }

    private func move(file: CoreDataFile, to location: Downloader.DownloadLocation) {
        if file.activeRevision?.validatedDecryptedFilePath() == nil && file.activeRevision?.blocksAreValid() == true {
            // Decrypt encrypted blocks to temp folder
            _ = try? file.activeRevision?.decryptFile()
        }
        do {
            try file.activeRevision?.move(to: location)
        } catch {
            Log.error("Move revision to \(location) failed", error: error, domain: .storage)
        }
    }

    private func checkMarkedAndInheriting(folders: [CoreDataFolder]) async throws {
        let folders = filterFolders(folders: folders)
        if folders.isEmpty {
            return
        }
        Log.debug("Checking marked folders: \(folders.count)", domain: .offlineAvailable)

        var incompleteFolders = [Folder]()

        try Task.checkCancellation()

        try await managedObjectContext.perform { [managedObjectContext] in
            // already scanned children - mark inheriting
            folders.forEach { folder in
                folder.children
                    .filter { $0.state != .deleted }
                    .forEach { $0.setIsInheritingOfflineAvailable(true) }

                if !folder.isChildrenListFullyFetched {
                    incompleteFolders.append(folder)
                }
            }
            try managedObjectContext.saveIfNeeded()
        }

        try Task.checkCancellation()

        // need to re-scan
        try await scanFolders(incompleteFolders)
    }

    private func scanFolders(_ folders: [CoreDataFolder]) async throws {
        guard !folders.isEmpty else {
            return
        }

        Log.debug("Scanning marked folders: \(folders.count)", domain: .offlineAvailable)
        try await withThrowingTaskGroup { [weak self] group in
            for folder in folders {
                group.addTask {
                    try await self?.scanFolder(folder: folder)
                }
            }
            try await group.waitForAll()
        }
    }

    private func scanFolder(folder: CoreDataFolder) async throws {
        let identifier = folder.identifier
        Log.debug("Scanning folder \(identifier)", domain: .offlineAvailable)

        let children = await withCheckedContinuation { continuation in
            var childrenIdentifiers = Set<AnyVolumeIdentifier>()
            downloader.scanChildren(
                of: folder,
                enumeration: { node in
                    childrenIdentifiers.insert(node.identifier.any())
                },
                completion: { [weak self] result in
                    let childFolders = self?.handleFolderChildren(result: result, children: childrenIdentifiers) ?? []
                    continuation.resume(returning: childFolders)
                }
            )
        }

        try Task.checkCancellation()

        Log.debug("Finished scanning folder \(identifier), found \(children.count) subfolders", domain: .offlineAvailable)
        try await scanFolders(children)
    }

    private func handleFolderChildren(result: Result<CoreDataFolder, Error>, children: Set<AnyVolumeIdentifier>) -> [CoreDataFolder] {
        var childFolders = [CoreDataFolder]()
        switch result {
        case .success(let folder):
            let identifier = folder.identifier
            var remoteIdentifiers = [AnyVolumeIdentifier]()

            managedObjectContext.performAndWait {
                guard let parent = CoreDataFolder.fetch(identifier: identifier, in: managedObjectContext) else {
                    Log.info("Parent folder is no longer exists in DB", domain: .offlineAvailable)
                    return
                }
                guard !parent.isDeleted && parent.isEligibleForAvailableOffline else {
                    Log.info("Parent folder is no longer marked as available offline or is deleted", domain: .offlineAvailable)
                    return
                }

                let nodes = Node.fetch(identifiers: children, allowSubclasses: true, in: managedObjectContext)
                var files = [CoreDataFile]()
                nodes.forEach { node in
                    if let folder = node as? CoreDataFolder {
                        childFolders.append(folder)
                    } else if let file = node as? CoreDataFile {
                        files.append(file)
                    }
                    node.setIsInheritingOfflineAvailable(true)
                }

                let remoteFiles = self.filterLocalAndRemote(files: files).remote
                remoteIdentifiers = remoteFiles.map { $0.identifierWithinManagedObjectContext.any() }
                notifyAdded(identifiers: remoteIdentifiers)

                try? managedObjectContext.saveIfNeeded()
            }
        case let .failure(error):
            Log.error("Failed to complete scan of 1 folder", error: error, domain: .offlineAvailable)
        }
        return childFolders
    }

    private func uncheckMarked(files: [CoreDataFile]) async {
        let files = filterFiles(files: files)
        if files.isEmpty {
            return
        }
        Log.info("Unmarked for Offline Available files: \(files.count)", domain: .offlineAvailable)

        await managedObjectContext.perform { [weak self] in
            self?.uncheckMarkedFilesInContext(files)
            try? self?.managedObjectContext.saveIfNeeded()
        }
    }

    private func uncheckMarkedFilesInContext(_ files: [CoreDataFile]) {
        files.forEach {
            $0.setIsInheritingOfflineAvailable(false)
            self.move(file: $0, to: .temporary)
        }

        let unmarkedIdentifiers = files.map { $0.identifierWithinManagedObjectContext.any() }
        notifyCancelled(identifiers: unmarkedIdentifiers)
    }

    private func uncheckMarked(folders: [CoreDataFolder]) async {
        let folders = filterFolders(folders: folders)
        if folders.isEmpty {
            return
        }

        await managedObjectContext.perform { [weak self] in
            guard let self else {
                return
            }

            uncheckMarkedFoldersInContext(folders)
            try? managedObjectContext.saveIfNeeded()
        }
    }

    private func uncheckMarkedFoldersInContext(_ folders: [CoreDataFolder]) {
        folders.forEach { folder in
            folder.setIsInheritingOfflineAvailable(false)

            let files = folder.children.compactMap { $0 as? CoreDataFile }
            uncheckMarkedFilesInContext(files)

            let folders = folder.children.compactMap { $0 as? CoreDataFolder }
            uncheckMarkedFoldersInContext(folders)
        }
    }

    // MARK: - Notifications

    private func notifyAdded(identifiers: [AnyVolumeIdentifier]) {
        notificationQueue.async {
            let value = self.addedSubject.value.union(identifiers)
            self.addedSubject.send(value)
        }
    }

    private func notifyCancelled(identifiers: [AnyVolumeIdentifier]) {
        notificationQueue.async {
            let value = self.cancelledSubject.value.union(identifiers)
            self.cancelledSubject.send(value)
        }
    }

    // MARK: - Filtering

    private func filterFiles(files: [File]) -> [File] {
        switch configuration {
        case .bothMyFilesAndPhotos:
            return files
        case .onlyMyFiles:
            return files.filter { !($0 is CoreDataPhoto) }
        case .onlyPhotos:
            return files.filter { $0 is CoreDataPhoto }
        }
    }

    private func filterFolders(folders: [Folder]) -> [Folder] {
        switch configuration {
        case .bothMyFilesAndPhotos:
            return folders
        case .onlyMyFiles:
            return folders
        case .onlyPhotos:
            return [] // Photos root cannot be marked offline available
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        let operation = AsynchronousBlockOperation { [weak self] in
            guard let self else {
                return
            }

            switch type {
            case .insert where anObject is CoreDataFile:
                try? await self.checkMarkedAndInheriting(files: [anObject as! CoreDataFile])
            case .insert where anObject is CoreDataFolder:
                try? await self.checkMarkedAndInheriting(folders: [anObject as! CoreDataFolder])
            case .delete where anObject is CoreDataFile:
                await self.uncheckMarked(files: [anObject as! CoreDataFile])
            case .delete where anObject is CoreDataFolder:
                await self.uncheckMarked(folders: [anObject as! CoreDataFolder])
            default:
                return
            }
            Log.info("Offline available state did change.", domain: .offlineAvailable)
        }
        processingQueue.addOperation(operation)
    }
}

#endif
