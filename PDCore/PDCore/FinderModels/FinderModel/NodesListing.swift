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

import Combine
import CoreData

public protocol NodesListing: AnyObject {
    var tower: Tower! { get }
    var childrenObserver: FetchedObjectsObserver<Node> { get }
    var sorting: SortPreference { get }
    func reportDecryptionError(for node: Node, underlyingError: Error)
    func reportEnumeratedItem(for node: Node)
}

extension NodesListing {
    
    // MARK: Children
    
    public func children() -> AnyPublisher<([Node], [Node]), Never> {
        self.childrenObserver.objectWillChange
        .map {
            let active = self.childrenObserver.fetchedObjects.filter { $0.state == .active && !$0.isTrashInheriting }
            let sortedActive = self.sorting.sort(active)

            let uploading = self.childrenObserver.fetchedObjects.filter { $0.state?.isUploading ?? false }
            let sortedUploading = self.sorting.sort(uploading)
            
            return (sortedActive, sortedUploading)
        }
        .eraseToAnyPublisher()
    }
    
    public func switchSorting(_ sort: SortPreference) {
        self.tower.localSettings.nodesSortPreference = sort
    }
    
    public func loadChildrenFromCache() {
        self.childrenObserver.start()
    }
    
    // MARK: Node Error Reporting

    /// Note: call from within NSManagedObjectContext!
    public func reportEnumeratedItem(for node: Node) {
        #if os(macOS)
        let reportableSyncItem = ReportableSyncItem(
            id: node.identifier.rawValue,
            modificationTime: Date(),
            filename: node.decryptedName,
            location: nil,
            mimeType: node.mimeType,
            fileSize: node.size,
            operation: .enumerateItems,
            state: .finished,
            progress: 100,
            errorDescription: nil
        )
        tower.syncStorage?.upsert(reportableSyncItem)
        #endif
    }

    public func reportDecryptionError(for node: Node, underlyingError: Error) {
        #if os(macOS)
        let reportableSyncItem = ReportableSyncItem(
            id: node.identifier.rawValue,
            modificationTime: Date(),
            filename: "Error: Not available",
            location: nil,
            mimeType: node.mimeType,
            fileSize: node.size,
            operation: .enumerateItems,
            state: .errored,
            progress: 0,
            errorDescription: "Access to file attribute (e.g., file name) not available. Please retry or contact support."
        )
        tower.syncStorage?.upsert(reportableSyncItem)
        #endif
    }
}
