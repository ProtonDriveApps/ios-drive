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

public final class OfflineSaver: NSObject {

    weak var storage: StorageManager?
    weak var downloader: Downloader?
    let connectionStateResource: ConnectionStateResource

    private var progress = Progress()
    private var fractionObservation: NSKeyValueObservation?
    @objc public dynamic var fractionCompleted: Double = 0
    
    var frc: NSFetchedResultsController<Node>!

    let rebuildProgressSubject = PassthroughSubject<Void, Never>()
    private var cancelables: Set<AnyCancellable> = []
    private var isCleaningUp = false

    init(
        clientConfig: APIService.Configuration,
        storage: StorageManager,
        downloader: Downloader,
        populatedStateController: PopulatedStateControllerProtocol,
        connectionStateResource: ConnectionStateResource
    ) {
        self.storage = storage
        self.downloader = downloader
        self.connectionStateResource = connectionStateResource

        super.init()
        
        self.trackReachability(toHost: clientConfig.apiOrigin)

        // Progress rebuilding is dangerous task because of KVO and subscriptions involved.
        // We want to make is as seldom as possible, so we wait a couple of seconds after last request
        rebuildProgressSubject
            .combineLatest(populatedStateController.state)
            .filter { _, state in state == .populated }
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .handleEvents(receiveOutput: { [weak self] _ in
                // Clear the old process with references to the children progresses as soon as possible
                self?.progress = Progress()
                Log.info("Did clear old Progress tracking", domain: .downloader)
            })
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.isCleaningUp else { return }
                self.rebuildProgress()
            }
            .store(in: &cancelables)
    }
        
    func start() {
        isCleaningUp = false
        storage?.backgroundContext.perform {
            self.subscribeToUpdates()
        }
    }
    
    func cleanUp() {
        self.isCleaningUp = true

        self.fractionObservation?.invalidate()
        self.fractionObservation = nil

        self.frc?.delegate = nil
        self.frc = nil
    }

    func add(cancellable: AnyCancellable) {
        cancelables.insert(cancellable)
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
    
    // Check that all marked nodes are downloaded and up to date
    private func checkMarkedAndInheriting(files: [File]) {
        Log.info("Marked for Offline Available files: \(files.count)", domain: .downloader)
        
        // already downloaded
        files.filter {
            $0.activeRevision?.blocksAreValid() == true
        }.forEach {
            self.move(file: $0, to: .offlineAvailable)
        }
        
        // need to download
        files.filter {
            $0.activeRevision?.blocksAreValid() != true
        }.filter { file in
            self.downloader?.presentOperationFor(file: file) == nil
        }.compactMap { file in
            self.downloader?.scheduleDownloadOfflineAvailable(cypherdataFor: file) {
                switch $0 {
                case .success:
                    self.move(file: file, to: .offlineAvailable)
                    Log.info("Offline available 1 file", domain: .downloader)
                case .failure:
                    Log.error("Failed to make offline available 1 file", error: nil, domain: .downloader)
                }
            }
        }.forEach { operation in
            // artificially increase fraction until progress will be properly rebuilt
            self.fractionCompleted += 0.01
        }
    }
    
    private func checkMarkedAndInheriting(folders: [Folder]) {
        Log.info("Marked for Offline Available folders: \(folders.count)", domain: .downloader)
        
        // already scanned children - mark inheriting
        folders.forEach { folder in
            folder.children.forEach { child in
                child.setIsInheritingOfflineAvailable(true)
            }
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
                    Log.info("Scanned 1 folder", domain: .downloader)
                case .failure:
                    Log.error("Failed to complete scan of 1 folder", error: nil, domain: .downloader)
                }
            })
        }.forEach { operation in
            // artificially increase fraction until progress will be properly rebuilt
            self.fractionCompleted += 0.01
        }
    }
    
    private func uncheckMarked(files: [File]) {
        Log.info("Unmarked for Offline Available files: \(files.count)", domain: .downloader)
        
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
        Log.info("Unmarked for Offline Available folders: \(folders.count)", domain: .downloader)
        
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
        file.activeRevision?.blocks.forEach {
            try? $0.move(to: location)
        }
    }
}

extension OfflineSaver: NSFetchedResultsControllerDelegate {
    private func subscribeToUpdates() {
        guard let storage = self.storage else {
            assertionFailure("Tried to create FRC without storage")
            return
        }
        self.frc = storage.subscriptionToOfflineAvailable(withInherited: true, moc: storage.backgroundContext)
        frc.delegate = self
        
        do {
            try frc.performFetch()
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
                case .insert where anObject is Folder:
                    self.checkMarkedAndInheriting(folders: [anObject as! Folder])
                case .delete where anObject is File:
                    self.uncheckMarked(files: [anObject as! File])
                case .delete where anObject is Folder:
                    self.uncheckMarked(folders: [anObject as! Folder])
                    
                    /* Cases of updates are handled by CloudSlot components of EventsProvider */
                    
                default: return // no need to rebuld progresses block for other cases of updates
                }
            }
        }
        
        Log.info("Offline available state did change. Attemot rebuild progress.", domain: .downloader)
        self.rebuildProgressSubject.send()
    }
    
    private func rebuildProgress() {
        // Progress can not forget old children and they always participate in fractionCompleted
        // so we need to create new Progress each time we know a lot of sessions were cancelled and will be re-added to Downloader
        // usage of Progress to trach completion rate of operations is an implementation detail of OfflineSaver,
        // even though higher levels of the app may create their own instances of Progress from this info
        
        Log.info("Rebuild progressBlock 🧨", domain: .downloader)
        
        self.fractionObservation?.invalidate()
        self.fractionObservation = nil
        
        self.progress = Progress()
        self.downloader?.queue.operations
            .filter { !$0.isCancelled && $0 is LegacyDownloadFileOperation }
            .compactMap { $0 as? OperationWithProgress }
            .forEach {
                self.progress.totalUnitCount += 1
                self.progress.addChild($0.progress, withPendingUnitCount: 1)
            }
        
        self.fractionObservation = self.progress.observe(\.fractionCompleted, options: .initial) { [weak self] progress, _ in
            guard let self = self else { return }
            self.fractionCompleted = progress.fractionCompleted
        }
    }
    
}
