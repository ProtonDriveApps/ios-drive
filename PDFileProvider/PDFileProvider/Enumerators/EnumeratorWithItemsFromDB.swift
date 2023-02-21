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

protocol EnumeratorWithItemsFromDB: LogObject {
    associatedtype Model: NodesListing
    var model: Model! { get }
    func reinitializeModelIfNeeded() throws
}

extension EnumeratorWithItemsFromDB {
    func fetchAllChildrenFromDB(_ observer: NSFileProviderEnumerationObserver) {
        let allChildren = self.model.childrenObserver.fetchedObjects
        ConsoleLogger.shared?.log("Fetched \(allChildren.count) nodes from DB", osLogType: Self.self)
        
        guard let moc = allChildren.first?.managedObjectContext else {
            observer.finishEnumerating(upTo: nil)
            return
        }
        
        moc.perform {
            let items = allChildren.map { NodeItem(node: $0) }
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
        }
    }
}
