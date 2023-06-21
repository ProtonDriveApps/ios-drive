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
import os.log

public final class TrashEnumerator: NSObject, NSFileProviderEnumerator, LogObject {
    public static var osLog: OSLog = OSLog(subsystem: "ProtonDriveFileProvider", category: "TrashEnumerator")
    
    private var _model: TrashModel! // backing property
    internal private(set) var model: TrashModel! {
        get {
            if _model == nil {
                _model = TrashModel(tower: tower)
            }
            return _model
        }
        set {
            _model = newValue
        }
    }
    private weak var tower: Tower!
    private var cancellables: [AnyCancellable] = []
    
    public init(tower: Tower) {
        self.tower = tower
    }
    
    public func invalidate() {
        self.cancellables.forEach { $0.cancel() }
        self.model = nil
    }
    
    // MARK: Enumeration
    
    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        ConsoleLogger.shared?.log("Enumerating items for Trash", osLogType: Self.self)
        
        Future { promise in
            self.model.fetchTrash { promise($0) }
        }.flatMap { _ in
            self.model.trashItems
                .first() // trashItems is a publisher which that never finishes, but here we are interested only in 1 subject from it
                .setFailureType(to: Error.self) // needed for iOS 13
        }.sink { completion in
            switch completion {
            case .finished:
                ConsoleLogger.shared?.log("Finished enumerating items for Trash", osLogType: Self.self)
                observer.finishEnumerating(upTo: nil)
            case .failure(let error):
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                observer.finishEnumeratingWithError(error)
            }
        } receiveValue: { value in
            ConsoleLogger.shared?.log("Enumerated \(value.count) items for Trash", osLogType: Self.self)
            observer.didEnumerate(value.map(NodeItem.init))
        }.store(in: &cancellables)
    }
    
    // MARK: Changes
    
    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.currentSyncAnchor(completionHandler)
    }
    
    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        self.enumerateChanges(observer, syncAnchor)
    }
}

extension TrashEnumerator: EnumeratorWithChanges {
    internal var shareID: String { self.model.shareID }
    internal var eventsManager: EventsSystemManager { self.tower }
    internal var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    internal var cloudSlot: CloudSlot { self.tower.cloudSlot! }
}
