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

public class FolderEnumerator: NSObject, NSFileProviderEnumerator, EnumeratorWithItemsFromAPI, EnumeratorWithItemsFromDB {
    private weak var tower: Tower!
    private let pageSize: Int
    private let nodeID: NodeIdentifier
    
    var shouldReenumerateItems: Bool
    var changeObserver: FileProviderChangeObserver?
    
    private var _model: FolderModel! // backing property
    internal private(set) var model: FolderModel! {
        get {
            // swiftlint:disable force_try
            try! reinitializeModelIfNeeded()
            // swiftlint:enable force_try
            return _model
        }
        set {
            _model = newValue
        }
    }
    
    internal var fetchFromAPICancellable: AnyCancellable?
    
    public init(tower: Tower,
                // We need to align the DB page size with the BE page size to allow switching from API fetch 
                // to DB fetch mid-way. This means that if page 0 is fetched from API, we can fetch page 1 from DB,
                // and we interpret the page size correctly. The FileProvider API only tells us the page number,
                // not the page size, so having the consistent size is on us.
                pageSize: Int = Constants.pageSizeForChildrenFetchAndEnumeration,
                changeObserver: FileProviderChangeObserver? = nil,
                nodeID: NodeIdentifier,
                shouldReenumerateItems: Bool = false) {
        self.tower = tower
        self.pageSize = pageSize
        self.nodeID = nodeID
        self.changeObserver = changeObserver
        self.shouldReenumerateItems = shouldReenumerateItems
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
        let observers = [observer, changeObserver].compactMap { $0 }
        changeObserver?.incrementSyncCounter()

        do {
            try self.reinitializeModelIfNeeded()
        } catch {
            observers.forEach { $0.finishEnumeratingWithError(Errors.mapToFileProviderError(Errors.failedToCreateModel)!) }
            Log.error("Failed to enumerate items due to model failing to be created: \(error)", domain: .fileProvider)
            return
        }
        Log.info("Enumerating items for \(~self.model.node)", domain: .fileProvider)
        
        self.model.loadFromCache()
        guard let moc = model.node.moc else {
            observers.forEach { $0.finishEnumeratingWithError(Errors.mapToFileProviderError(Errors.failedToCreateModel)!) }
            return
        }

        let intPage = page.int
        if moc.performAndWait({ !self.model.node.isChildrenListFullyFetched }) {
            self.fetchPageFromAPI(intPage, observers: observers)
        } else {
            self.fetchPageFromDB(intPage, pageSize: pageSize, observers: observers)
        }
    }

    // MARK: Changes
    
    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.currentSyncAnchor(completionHandler)
    }
    
    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        let observers = [observer, changeObserver].compactMap { $0 }
        self.enumerateChanges(observers, syncAnchor)
    }
}

extension FolderEnumerator: EnumeratorWithChanges {
    internal var shareID: String { self.nodeID.shareID }
    internal var eventsManager: EventsSystemManager { self.tower }
    internal var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    internal var cloudSlot: CloudSlotProtocol { self.tower.cloudSlot! }
}
