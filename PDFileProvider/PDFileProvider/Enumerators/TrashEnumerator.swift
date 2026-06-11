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
import PDCore
import Combine

public final class TrashEnumerator: NSObject, NSFileProviderEnumerator {
    private weak var tower: Tower!
    internal let keepDownloadedManager: KeepDownloadedEnumerationManager
    private var cancellables: [AnyCancellable] = []

    let enumerationObserver: EnumerationObserverProtocol?

    let displayChangeEnumerationDetails: Bool

    var shouldReenumerateItems: Bool = false {
        didSet {
            Log.trace("shouldReenumerateItems = \(shouldReenumerateItems)")
        }
    }

    public init(tower: Tower,
                keepDownloadedManager: KeepDownloadedEnumerationManager,
                enumerationObserver: EnumerationObserverProtocol? = nil,
                displayChangeEnumerationDetails: Bool) {
        Log.trace()
        self.tower = tower
        self.keepDownloadedManager = keepDownloadedManager
        self.enumerationObserver = enumerationObserver
        self.displayChangeEnumerationDetails = displayChangeEnumerationDetails
    }
    
    public func invalidate() {
        Log.trace()
        self.cancellables.forEach { $0.cancel() }
    }
    
    // MARK: Enumeration
    
    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Log.trace()
        Log.event(.enumerateItems(.started(.init(containerType: .trashContainer, pageNumber: page.int))))
        observer.finishEnumerating(upTo: nil)
        Log.event(.enumerateItems(.succeeded(.init(containerType: .trashContainer, itemEnumerationMode: .db, enumeratedItemIDs: [], hasMorePages: false))))
    }
    
    // MARK: Changes
    
    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        Log.trace()
        self.currentSyncAnchor(completionHandler)
    }
    
    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        Log.trace()
        Log.event(.enumerateChanges(.started(.init(containerType: .trashContainer, syncAnchor: syncAnchor.rawValue.base64EncodedString()))))
        observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
        Log.event(.enumerateChanges(.succeeded(.init(containerType: .trashContainer, updatedItemIDs: [], deletedItemIDs: [], newSyncAnchor: nil))))
    }
}

extension TrashEnumerator: EnumeratorWithChanges {
    internal var shareID: String { self.tower.rootFolderIdentifier(moc: self.tower.storage.backgroundContext)!.shareID }
    internal var eventsManager: EventsSystemManager { self.tower }
    internal var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    internal var cloudSlot: CloudSlotProtocol { self.tower.cloudSlot! }
}
