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

import CoreData
import PDClient
import Combine
#if canImport(UIKit)
import UIKit
#endif

public final class LegacyOfflineSaver: BaseOfflineSaver, OfflineSaverProtocol {
    weak var storage: StorageManager?
    weak var downloader: Downloader?
    let connectionStateResource: ConnectionStateResource

    private var progress = Progress()
    private var fractionObservation: NSKeyValueObservation?

    var frc: NSFetchedResultsController<Node>!

    let rebuildProgressSubject = PassthroughSubject<Void, Never>()
    private var cancelables: Set<AnyCancellable> = []
    private var isCleaningUp = false
    @ThreadSafe private var markedIdentifiers = Set<AnyVolumeIdentifier>()
    private var fractionCompletedSubject = CurrentValueSubject<Double, Never>(0)

    public var state: AnyPublisher<OfflineSaverState, Never> {
        fractionCompletedSubject
            .map { value in
                if value < 0.001 || value > 0.99 {
                    return OfflineSaverState.inactive
                } else {
                    return OfflineSaverState.progress(value)
                }
            }
            .eraseToAnyPublisher()
    }
    public var isDownloading: Bool {
        let isEmpty = downloader?.queue.operations.isEmpty ?? true
        return !isEmpty
    }

    public init(
        configuration: OfflineSaverConfiguration,
        storage: StorageManager,
        downloader: Downloader,
        populatedStateController: PopulatedStateControllerProtocol,
        connectionStateResource: ConnectionStateResource
    ) {
        self.storage = storage
        self.downloader = downloader
        self.connectionStateResource = connectionStateResource

        super.init(configuration: configuration)

        self.trackReachability()

        // Progress rebuilding is dangerous task because of KVO and subscriptions involved.
        // We want to make is as seldom as possible, so we wait a couple of seconds after last request
        rebuildProgressSubject
            .combineLatest(populatedStateController.state)
            .filter { _, state in state == .populated }
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .handleEvents(receiveOutput: { [weak self] _ in
                // Clear the old process with references to the children progresses as soon as possible
                self?.progress = Progress()
                Log.info("Did clear old Progress tracking", domain: .offlineAvailable)
            })
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.isCleaningUp else { return }
                self.rebuildProgress()
            }
            .store(in: &cancelables)

        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let state = self?.connectionStateResource.currentState else { return }
                self?.handle(state: state)
            }
            .store(in: &cancelables)
        #endif
    }

    public func start() {
        isCleaningUp = false
        storage?.backgroundContext.perform {
            self.subscribeToUpdates()
        }
    }

    public func cleanUp() {
        self.isCleaningUp = true

        self.fractionObservation?.invalidate()
        self.fractionObservation = nil

        self.frc?.delegate = nil
        self.frc = nil
    }

    internal func markedFoldersAndFiles() -> (folders: [Folder], files: [File]) {
        let folders = frc?.sections?.first { info in
            info.indexTitle == NSNumber(value: true).stringValue
        }?.objects?.compactMap {
            $0 as? Folder
        } ?? []

        let files = frc?.sections?.first(where: { info in
            info.indexTitle == NSNumber(value: false).stringValue
        })?.objects?.compactMap {
            $0 as? File
        } ?? []

        return (folders, files)
    }

    internal func checkEverything() {
        let (folders, files) = self.markedFoldersAndFiles()

        self.checkMarkedAndInheriting(files: files)
        self.checkMarkedAndInheriting(folders: folders)
    }

    private func filter(files: [File], isDownloaded: Bool) -> [File] {
        files.filter { $0.activeRevision?.isAvailableLocally() == isDownloaded }
    }

    // Check that all marked nodes are downloaded and up to date
    private func checkMarkedAndInheriting(files: [File]) {
        let files = filterFiles(files: files)
        if files.isEmpty {
            return
        }
        Log.info("Marked for Offline Available files: \(files.count)", domain: .offlineAvailable)

        markedIdentifiers.formUnion(files.map { $0.identifier.any() })
        let downloaded = filter(files: files, isDownloaded: true)
        let needToBeDownload = filter(files: files, isDownloaded: false)
        downloaded
            .forEach {
                self.move(file: $0, to: .offlineAvailable)
            }

        // need to download
        needToBeDownload
            .filter { file in
                self.downloader?.presentOperationFor(file: file) == nil
            }.compactMap { file in
                self.downloader?.scheduleDownloadOfflineAvailable(cypherdataFor: file) {
                    switch $0 {
                    case .success:
                        self.move(file: file, to: .offlineAvailable)
                        Log.info("Offline available 1 file", domain: .offlineAvailable)
                    case let .failure(error):
                        Log.error("Failed to make offline available 1 file", error: error, domain: .offlineAvailable)
                    }
                }
            }.forEach { operation in
                // artificially increase fraction until progress will be properly rebuilt
                fractionCompletedSubject.send(fractionCompletedSubject.value + 0.01)
            }
    }

    private func checkMarkedAndInheriting(folders: [Folder]) {
        let folders = filterFolders(folders: folders)
        if folders.isEmpty {
            return
        }
        Log.info("Marked for Offline Available folders: \(folders.count)", domain: .offlineAvailable)

        // already scanned children - mark inheriting
        folders.forEach { folder in
            folder.children
                .filter { $0.state != .deleted }
                .forEach { $0.setIsInheritingOfflineAvailable(true) }
        }

        // need to re-scan
        folders.filter {
            !$0.isChildrenListFullyFetched
        }.compactMap { folder in
            self.downloader?.scanChildren(of: folder,
             enumeration: { node in
                node.setIsInheritingOfflineAvailable(true)
            }, completion: { result in
                switch result {
                case .success:
                    Log.info("Scanned 1 folder", domain: .offlineAvailable)
                case .failure:
                    Log.error("Failed to complete scan of 1 folder", error: nil, domain: .offlineAvailable)
                }
            })
        }.forEach { operation in
            // artificially increase fraction until progress will be properly rebuilt
            fractionCompletedSubject.send(fractionCompletedSubject.value + 0.01)
        }
    }

    private func uncheckMarked(files: [File]) {
        let files = filterFiles(files: files)
        if files.isEmpty {
            return
        }
        Log.info("Unmarked for Offline Available files: \(files.count)", domain: .offlineAvailable)
        markedIdentifiers.subtract(files.map { $0.identifier.any() })

        files.forEach {
            $0.setIsInheritingOfflineAvailable(false)
            self.move(file: $0, to: .temporary)
        }

        let identifiers = files
            .filter { !$0.shareID.isEmpty || !$0.directShares.isEmpty }
            .map(\.identifier)
        self.downloader?.cancel(operationsOf: identifiers)
    }

    private func uncheckMarked(folders: [Folder]) {
        let folders = filterFolders(folders: folders)
        if folders.isEmpty {
            return
        }
        Log.info("Unmarked for Offline Available folders: \(folders.count)", domain: .offlineAvailable)

        folders.forEach { parent in
            parent.setIsInheritingOfflineAvailable(false)

            let files = parent.children.compactMap { $0 as? File }
            self.uncheckMarked(files: files)

            let folders = parent.children.compactMap { $0 as? Folder }
            self.uncheckMarked(folders: folders)
        }

        self.downloader?.cancel(operationsOf: folders.map(\.identifier))
    }

    private func move(file: File, to location: Downloader.DownloadLocation) {
        if file.activeRevision?.validatedDecryptedFilePath() == nil && file.activeRevision?.blocksAreValid() == true {
            // Decrypt to temp folder
            _ = try? file.activeRevision?.decryptFile()
        }
        try? file.activeRevision?.move(to: location)
    }

    // MARK: - Reachability

    internal func trackReachability() {
        connectionStateResource.state.sink { [weak self] state in
            self?.handle(state: state)
        }
        .store(in: &cancelables)
    }

    private func handle(state: NetworkState) {
        switch state {
        case .reachable:
            self.storage?.backgroundContext.perform {
                self.checkEverything()
                self.rebuildProgressSubject.send()
            }
        case .unreachable:
            // check if something is not downloaded properly - and artificially add tiny fraction so progress will be claimed started
            guard let context = storage?.backgroundContext else { return }
            context.perform { [weak self] in
                let revisions = self?.markedFoldersAndFiles().files.compactMap(\.activeRevision) ?? []
                if revisions.contains(where: { !$0.isAvailableLocally() }) {
                    self?.notifyFractionUpdate()
                }
            }
        }
    }

    private func notifyFractionUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.fractionCompletedSubject.send(self.fractionCompletedSubject.value + 0.01)
        }
    }
}

extension LegacyOfflineSaver: NSFetchedResultsControllerDelegate {
    private func subscribeToUpdates() {
        guard let storage = self.storage else {
            assertionFailure("Tried to create FRC without storage")
            return
        }
        self.frc = storage.subscriptionToOfflineAvailable(withInherited: true, moc: storage.backgroundContext)
        frc.delegate = self

        do {
            try frc.performFetch()
            storage.backgroundContext.perform { [weak self] in
                self?.checkEverything()
            }
        } catch let error {
            assertionFailure(error.localizedDescription)
            Log.error("Failed to fetch nodes marked for Offline Available", error: nil, domain: .storage)
        }
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange anObject: Any,
                           at indexPath: IndexPath?,
                           for type: NSFetchedResultsChangeType,
                           newIndexPath: IndexPath?)
    {
        // To break possible recursive call
        // When recursive call happens, coreData will throw error 132001 when save
        DispatchQueue.global().async {
            controller.managedObjectContext.perform {
                switch type {
                case .insert where anObject is File:
                    self.checkMarkedAndInheriting(files: [anObject as! File])
                    Log.info("Offline available state did change (.insert file).", domain: .offlineAvailable)
                    self.rebuildProgressSubject.send()
                case .insert where anObject is Folder:
                    self.checkMarkedAndInheriting(folders: [anObject as! Folder])
                    Log.info("Offline available state did change (.insert folder).", domain: .offlineAvailable)
                    self.rebuildProgressSubject.send()
                case .delete where anObject is File:
                    self.uncheckMarked(files: [anObject as! File])
                    Log.info("Offline available state did change (.delete file).", domain: .offlineAvailable)
                    self.rebuildProgressSubject.send()
                case .delete where anObject is Folder:
                    self.uncheckMarked(folders: [anObject as! Folder])
                    Log.info("Offline available state did change (.delete folder).", domain: .offlineAvailable)
                    self.rebuildProgressSubject.send()

                    /* Cases of updates are handled by CloudSlot components of EventsProvider */

                default: return // no need to rebuld progresses block for other cases of updates
                }
            }
        }
    }

    private func rebuildProgress() {
        // Progress can not forget old children and they always participate in fractionCompleted
        // so we need to create new Progress each time we know a lot of sessions were cancelled and will be re-added to Downloader
        // usage of Progress to trach completion rate of operations is an implementation detail of OfflineSaver,
        // even though higher levels of the app may create their own instances of Progress from this info

        Log.info("Rebuild progressBlock 🧨", domain: .offlineAvailable)

        self.fractionObservation?.invalidate()
        self.fractionObservation = nil

        self.progress = Progress()
        self.downloader?.queue.operations
            .filter { !$0.isCancelled }
            .compactMap {
                // TODO: we should use new operation. (But that crashes for whatever reason due to progress subscriptions).
                // This will get deleted once we switch to SDK. See `Downloader.scheduleDownloadOfflineAvailable` for more info.
                $0 as? LegacyDownloadFileOperation
            }
            .filter { operation in
                // Filter only files marked as available offline
                let progress = operation.progressTracker(direction: .downstream)
                return markedIdentifiers.contains(where: { identifier in
                    progress.matches(identifier.id)
                })
            }
            .forEach {
                self.progress.totalUnitCount += 1
                self.progress.addChild($0.progress, withPendingUnitCount: 1)
            }

        self.fractionObservation = self.progress.observe(\.fractionCompleted, options: .initial) { [weak self] progress, _ in
            guard let self = self else { return }
            fractionCompletedSubject.send(progress.fractionCompleted)
        }
    }

}
