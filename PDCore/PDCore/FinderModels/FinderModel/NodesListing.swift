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

public protocol NodesListing: AnyObject {
    var tower: Tower! { get }
    var childrenObserver: FetchedObjectsObserver<Node> { get }
    var sorting: SortPreference { get }
}

extension NodesListing {
    public func children() -> AnyPublisher<([Node], [Node]), Never> {
        self.childrenObserver.objectWillChange
        .map {
            let active = self.childrenObserver.fetchedObjects.filter { $0.state == .active && !$0.isTrashInheriting }
            let sortedActive = self.sorting.sort(active)

            let uploading = self.childrenObserver.fetchedObjects.filter { $0.state?.isUploading ?? false }
            let sortedUploading = self.sorting.sort(uploading)
            
            return (sortedActive, sortedUploading)
        }
        .removeDuplicates(by: { previous, current in
            return previous.0 == current.0 && previous.1 == current.1
        })
        .eraseToAnyPublisher()
    }
    
    public func switchSorting(_ sort: SortPreference) {
        self.tower.localSettings.nodesSortPreference = sort
    }
    
    public func loadChildrenFromCache() {
        self.childrenObserver.start()
    }
}
