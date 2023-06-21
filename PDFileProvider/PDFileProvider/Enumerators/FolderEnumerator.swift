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

import FileProvider
import Combine
import PDCore
import os.log

public class FolderEnumerator: NSObject, NSFileProviderEnumerator, EnumeratorWithItemsFromAPI, EnumeratorWithItemsFromDB, LogObject {
    
    public static var osLog: OSLog = OSLog(subsystem: "ProtonDriveFileProvider", category: "FolderEnumerator")
    
    private weak var tower: Tower!
    private let nodeID: NodeIdentifier
    
    private var _model: FolderModel! // backing property
    internal private(set) var model: FolderModel! {
        get {
            // swiftlint:disable force_try
            try! reinitializeModelIfNeeded()
            return _model
        }
        set {
            _model = newValue
        }
    }
    
    internal var fetchFromAPICancellable: AnyCancellable?
    
    public init(tower: Tower, nodeID: NodeIdentifier) throws {
        self.tower = tower
        self.nodeID = nodeID
        super.init()
    }
    
    public func invalidate() {
        self.fetchFromAPICancellable?.cancel()
        self.model = nil
    }
    
    func reinitializeModelIfNeeded() throws {
        guard _model == nil else { return }
        self.model = try FolderModel(tower: tower, nodeID: nodeID)
    }
    
    // MARK: Enumeration
    
    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        do {
            try self.reinitializeModelIfNeeded()
        } catch {
            observer.finishEnumeratingWithError(Errors.mapToFileProviderError(Errors.failedToCreateModel)!)
            ConsoleLogger.shared?.log("Failed to enumerate items due to model failing to be created", osLogType: Self.self)
            return
        }
        ConsoleLogger.shared?.log("Enumerating items for \(~self.model.node)", osLogType: Self.self)
        
        self.model.loadFromCache()
        if !self.model.node.isChildrenListFullyFetched {
            self.fetchAllPagesFromAPI(observer)
        } else {
            self.fetchAllChildrenFromDB(observer)
        }
    }

    // MARK: Changes
    
    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.currentSyncAnchor(completionHandler)
    }
    
    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        self.enumerateChanges(observer, syncAnchor)
    }
}

extension FolderEnumerator: EnumeratorWithChanges {
    internal var shareID: String { self.nodeID.shareID }
    internal var eventsManager: EventsSystemManager { self.tower }
    internal var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    internal var cloudSlot: CloudSlot { self.tower.cloudSlot! }
}
