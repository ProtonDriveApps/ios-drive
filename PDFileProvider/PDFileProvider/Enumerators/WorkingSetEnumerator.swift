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

public final class WorkingSetEnumerator: NSObject, NSFileProviderEnumerator, EnumeratorWithItemsFromDB {

    private weak var tower: Tower!
    
    private var _model: ActivityModel! // backing property
    internal private(set) var model: ActivityModel! {
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
    
    private let pageSize: Int

    var shouldReenumerateItems: Bool
    var changeObserver: FileProviderChangeObserver?

    public init(tower: Tower,
                pageSize: Int = 5_000,
                changeObserver: FileProviderChangeObserver? = nil,
                shouldReenumerateItems: Bool = false) {
        self.tower = tower
        self.pageSize = pageSize
        self.changeObserver = changeObserver
        self.shouldReenumerateItems = shouldReenumerateItems
    }

    public func invalidate() {
        self.model = nil
    }

    func reinitializeModelIfNeeded() throws {
        guard _model == nil else { return }
        self.model = try ActivityModel(tower: tower)
    }

    // MARK: Enumeration

    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let observers = [observer, changeObserver].compactMap { $0 }
        changeObserver?.incrementSyncCounter()
        
        do {
            try self.reinitializeModelIfNeeded()
        } catch {
            observer.finishEnumeratingWithError(Errors.mapToFileProviderError(Errors.failedToCreateModel)!)
            Log.error("Failed to enumerate items due to model failing to be created", domain: .fileProvider)
            // if we cannot create a model, there's no point in accessing the model for enumeration later
            return
        }
        Log.info("Enumerating items for Working Set", domain: .fileProvider)
        self.model.loadFromCache()
        self.fetchPageFromDB(page.int, pageSize: pageSize, observers: observers)
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

extension WorkingSetEnumerator: EnumeratorWithChanges {
    internal var shareID: String { self.model.shareID }
    internal var eventsManager: EventsSystemManager { self.tower }
    internal var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    internal var cloudSlot: CloudSlot { self.tower.cloudSlot! }
}
