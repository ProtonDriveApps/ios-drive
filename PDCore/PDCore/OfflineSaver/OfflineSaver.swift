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
import os.log
import Reachability
import PDClient

public final class OfflineSaver: NSObject, LogObject {
    public static let osLog: OSLog = .init(subsystem: "ch.protondrive.PDCore", category: "OfflineSaver")

    weak var storage: StorageManager?
    weak var downloader: Downloader?
    var reachability: Reachability?
    
    private var progress = Progress()
    private var rebuildProgressesBlock: DispatchWorkItem?
    private var fractionObservation: NSKeyValueObservation?
    @objc public dynamic var fractionCompleted: Double = 0
    
    var frc: NSFetchedResultsController<Node>!
    
    init(clientConfig: APIService.Configuration, storage: StorageManager, downloader: Downloader) {
        self.storage = storage
        self.downloader = downloader
        self.reachability = nil
        
        super.init()
        
        self.trackReachability(toHost: clientConfig.host)
    }
        
    func start() {
        storage?.backgroundContext.perform {
            self.subscribeToUpdates()
        }
        
        do {
            try reachability?.startNotifier()
        } catch let error {
            assert(false, error.localizedDescription)
            ConsoleLogger.shared?.log(error, osLogType: OfflineSaver.self)
        }
    }
    
    func cleanUp() {
        self.reachability?.stopNotifier()
        self.reachability?.whenReachable = nil
        self.reachability?.whenUnreachable = nil
        self.reachability = nil
        
        self.rebuildProgressesBlock?.cancel()
        self.rebuildProgressesBlock = nil

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
    
    // Check that all marked nodes are downloaded and up to date
    private func checkMarkedAndInheriting(files: [File]) {
        ConsoleLogger.shared?.log("Marked for Offline Available files: \(files.count)", osLogType: OfflineSaver.self)
        
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
                    ConsoleLogger.shared?.log("Offline available 1 file", osLogType: OfflineSaver.self)
                case .failure:
                    ConsoleLogger.shared?.log("Failed to make offline available 1 file", osLogType: OfflineSaver.self)
                }
            }
        }.forEach { operation in
            // artificially increase fraction until progress will be properly rebuilt
            self.fractionCompleted += 0.01
        }
    }
    
    private func checkMarkedAndInheriting(folders: [Folder]) {
        ConsoleLogger.shared?.log("Marked for Offline Available folders: \(folders.count)", osLogType: OfflineSaver.self)
        
        // already scanned children - mark inheriting
        folders.forEach { folder in
            folder.children.forEach { child in
                child.isInheritingOfflineAvailable = true
            }
        }

        // need to re-scan
        folders.filter {
            !$0.isChildrenListFullyFetched
        }.compactMap { folder in
            self.downloader?.scanChildren(of: folder,
             enumeration: { node in
                node.isInheritingOfflineAvailable = true
            }, completion: { result in
                switch result {
                case .success:
                    ConsoleLogger.shared?.log("Scanned 1 folder", osLogType: OfflineSaver.self)
                case .failure:
                    ConsoleLogger.shared?.log("Failed to complete scan of 1 folder", osLogType: OfflineSaver.self)
                }
            })
        }.forEach { operation in
            // artificially increase fraction until progress will be properly rebuilt
            self.fractionCompleted += 0.01
        }
    }
    
    private func uncheckMarked(files: [File]) {
        ConsoleLogger.shared?.log("Unmarked for Offline Available files: \(files.count)", osLogType: OfflineSaver.self)
        
        files.forEach {
            $0.isInheritingOfflineAvailable = false
            self.move(file: $0, to: .temporary)
        }
        
        self.downloader?.cancel(operationsOf: files.map(\.identifier))
    }
    
    private func uncheckMarked(folders: [Folder]) {
        ConsoleLogger.shared?.log("Unmarked for Offline Available folders: \(folders.count)", osLogType: OfflineSaver.self)
        
        folders.forEach { parent in
            parent.isInheritingOfflineAvailable = false
            
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
            ConsoleLogger.shared?.log("Failed to fetch nodes marked for Offline Available", osLogType: OfflineSaver.self)
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange anObject: Any,
                           at indexPath: IndexPath?,
                           for type: NSFetchedResultsChangeType,
                           newIndexPath: IndexPath?)
    {
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
        
        self.requestProgressBlockUpdate()
    }
    
    internal func requestProgressBlockUpdate() {
        // Progress rebuilding is dangerous task because of KVO and subscriptions involved.
        // We want to make is as seldom as possible, so we wait a couple of seconds after last request
        self.rebuildProgressesBlock?.cancel()
        self.rebuildProgressesBlock = DispatchWorkItem(block: self.rebuildProgress)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: self.rebuildProgressesBlock!)
    }
    
    private func rebuildProgress() {
        // Progress can not forget old children and they always participate in fractionCompleted
        // so we need to create new Progress each time we know a lot of sessions were cancelled and will be re-added to Downloader
        // usage of Progress to trach completion rate of operations is an implementation detail of OfflineSaver,
        // even though higher levels of the app may create their own instances of Progress from this info
        
        ConsoleLogger.shared?.log("Rebuild progressBlock 🧨", osLogType: OfflineSaver.self)
        
        self.fractionObservation?.invalidate()
        self.fractionObservation = nil
        
        self.progress = Progress()
        self.downloader?.queue.operations
            .filter { !$0.isCancelled && $0 is DownloadFileOperation }
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
