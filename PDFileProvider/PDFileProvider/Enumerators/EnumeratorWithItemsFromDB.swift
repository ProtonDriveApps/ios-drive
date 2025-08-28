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

protocol EnumeratorWithItemsFromDB {
    associatedtype Model: NodesListing
    var model: Model! { get }
    func reinitializeModelIfNeeded() throws
}

/// "Item" enumerations are when listing the contents of a directory.
extension EnumeratorWithItemsFromDB {
    
    func fetchPageFromDB(_ page: Int, pageSize: Int, observers: [NSFileProviderEnumerationObserver]) {
        Log.trace()

        let allChildren = self.model.childrenObserver.fetchedObjects
        Log.info("Fetched \(allChildren.count) nodes from DB", domain: .enumerating)
        
        let childrenGroups = allChildren.splitInGroups(of: pageSize)
        guard childrenGroups.count > page else {
            observers.forEach { $0.finishEnumerating(upTo: nil) }
            return
        }
        var children = childrenGroups[page]

        guard let moc = allChildren.first?.managedObjectContext else {
            observers.forEach { $0.finishEnumerating(upTo: nil) }
            return
        }

        #if os(macOS)
        let originalChildrenCount = children.count
        moc.performAndWait {
            // exclude drafts from enumeration
            children = children.filter {
                guard let file = $0 as? File else { return true }
                return !file.isDraft()
            }
        }
        let draftsCount = originalChildrenCount - children.count
        #else
        let draftsCount = 0
        #endif

        let items = children.compactMap {
            do {
                return try NodeItem(node: $0)
            } catch {
                self.model.reportDecryptionError(for: $0, underlyingError: error)
                return nil
            }
        }
        observers.forEach { $0.didEnumerate(items) }

        guard (items.count + draftsCount) == pageSize else {
            observers.forEach { $0.finishEnumerating(upTo: nil) }
            return
        }

        let nextPage = page + 1
        let providerPage = NSFileProviderPage(nextPage)
        observers.forEach { $0.finishEnumerating(upTo: providerPage) }
    }
}
