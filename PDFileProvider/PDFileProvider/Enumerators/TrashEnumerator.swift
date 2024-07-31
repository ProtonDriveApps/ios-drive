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
    private var cancellables: [AnyCancellable] = []

    var changeObserver: FileProviderChangeObserver?
    var shouldReenumerateItems: Bool = false

    public init(tower: Tower, changeObserver: FileProviderChangeObserver? = nil) {
        self.tower = tower
        self.changeObserver = changeObserver
    }
    
    public func invalidate() {
        self.cancellables.forEach { $0.cancel() }
    }
    
    // MARK: Enumeration
    
    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        observer.finishEnumerating(upTo: nil)
    }
    
    // MARK: Changes
    
    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.currentSyncAnchor(completionHandler)
    }
    
    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
    }
}

extension TrashEnumerator: EnumeratorWithChanges {
    internal var shareID: String { self.tower.rootFolderIdentifier()!.shareID }
    internal var eventsManager: EventsSystemManager { self.tower }
    internal var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    internal var cloudSlot: CloudSlot { self.tower.cloudSlot! }
}
