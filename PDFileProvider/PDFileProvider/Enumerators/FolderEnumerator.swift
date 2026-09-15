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
    typealias Model = FolderModel

    private weak var tower: Tower!
    internal let keepDownloadedManager: KeepDownloadedEnumerationManager
    private let pageSize: Int
    private let nodeID: NodeIdentifier
    let displayChangeEnumerationDetails: Bool
    var displayEnumeratedItems: Bool

    internal let enumerationObserver: EnumerationObserverProtocol?

    internal private(set) var model: FolderModel?

    internal var fetchFromAPICancellable: AnyCancellable?
    var resyncEnumerationTask: Task<Void, Never>?

    public init(tower: Tower,
                keepDownloadedManager: KeepDownloadedEnumerationManager,
                // We need to align the DB page size with the BE page size to allow switching from API fetch
                // to DB fetch mid-way. This means that if page 0 is fetched from API, we can fetch page 1 from DB,
                // and we interpret the page size correctly. The FileProvider API only tells us the page number,
                // not the page size, so having the consistent size is on us.
                pageSize: Int = Constants.pageSizeForChildrenFetchAndEnumeration,
                nodeID: NodeIdentifier,
                enumerationObserver: EnumerationObserverProtocol? = nil,
                displayChangeEnumerationDetails: Bool = false,
                displayEnumeratedItems: Bool = false
    ) {
        Log.trace()
        self.tower = tower
        self.keepDownloadedManager = keepDownloadedManager
        self.pageSize = pageSize
        self.nodeID = nodeID
        self.enumerationObserver = enumerationObserver
        self.displayChangeEnumerationDetails = displayChangeEnumerationDetails
        self.displayEnumeratedItems = displayEnumeratedItems
    }

    public func invalidate() {
        Log.trace()
        resyncEnumerationTask?.cancel()
        fetchFromAPICancellable?.cancel()
        model = nil
    }

    func reinitializeModelIfNeeded() throws -> FolderModel {
        Log.trace()
        if let model { return model }
        let model = try FolderModel(tower: tower, nodeID: nodeID)
        self.model = model
        return model
    }

    // MARK: Enumeration

    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Log.event(.enumerateItems(.started(.init(containerType: .folder(nodeID.nodeID), pageNumber: page.int))))

        let observers = [observer, enumerationObserver?.items as? NSFileProviderEnumerationObserver].compactMap { $0 }

        let pageNumber = page.rawValue.first ?? 0

        enumerationObserver?.items.didStartEnumeratingItems(name: "Page \(pageNumber.description)")

        let model: FolderModel
        do {
            model = try self.reinitializeModelIfNeeded()
        } catch {
            observers.forEach { $0.finishEnumeratingWithError(Errors.mapLegacyErrorToFileProviderError(Errors.failedToCreateModel)) }
            Log.event(.enumerateItems(.failed(.init(containerType: .folder(nodeID.nodeID), errorMessage: "Failed to enumerate items due to model failing to be created"))))
            return
        }

        model.loadFromCache()
        guard let moc = model.node.moc else {
            observers.forEach { $0.finishEnumeratingWithError(Errors.mapLegacyErrorToFileProviderError(Errors.failedToCreateModel)) }
            Log.event(.enumerateItems(.failed(.init(containerType: .folder(nodeID.nodeID), errorMessage: "Failed to enumerate items due to model.node.moc being nil"))))
            return
        }

        let intPage = page.int
        if moc.performAndWait({ !model.node.isChildrenListFullyFetched }) {
            self.fetchPageFromAPI(.folder(nodeID.nodeID), intPage, observers: observers, model: model, moc: moc)
        } else {
            self.fetchPageFromDB(.folder(nodeID.nodeID), intPage, pageSize: pageSize, observers: observers, model: model)
        }
    }

    // MARK: Changes

    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        Log.trace("Folder enumeration \(nodeID.rawValue)", domain: .enumerating)
        self.currentSyncAnchor(shareID: nodeID.shareID, completionHandler)
    }

    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        Log.trace("Folder enumeration \(nodeID.rawValue)", domain: .enumerating)
        let observers = [observer, enumerationObserver?.changes as? NSFileProviderChangeObserver].compactMap { $0 }
        self.enumerateChanges(nodeID.shareID, self is RootEnumerator ? .rootContainer : .folder(nodeID.rawValue), observers, syncAnchor, "FolderEnumerator for \(nodeID.rawValue)")
    }
}

extension FolderEnumerator: EnumeratorWithChanges {
    var eventsManager: EventsSystemManager { self.tower }
    var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    var cloudSlot: CloudSlotProtocol { self.tower.cloudSlot! }
    // Intentionally nil: full resync is coordinated through the working set enumerator only
    // (see FileProviderExtension.reenumerateIfNecessary signalling .workingSet).
    var resyncEnumerationService: ResyncEnumerationService? { nil }
}
