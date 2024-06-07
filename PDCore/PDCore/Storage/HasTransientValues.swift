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

import CoreData

#if os(iOS)
protocol HasTransientValues {
    var _observation: Any? { get set }
}

extension HasTransientValues where Self: NSManagedObject {
    /// This observer checks if the object has changed in other contexts and discards transient values
    func subscribeToContexts() -> Any {
        return NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave,
                                                      object: nil,
                                                      queue: nil) { [weak self] notification in
            if let changedContext = notification.object as? NSManagedObjectContext,
               changedContext != self?.managedObjectContext,
               changedContext.parent != self?.managedObjectContext,
               let userInfo = notification.userInfo,
               let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
               let objectID = self?.objectID,
               updated.map(\.objectID).contains(objectID)
            {
                guard let moc = self?.moc else { return }
                moc.perform { [weak self] in
                    if let self = self, !self.isDeleted {
                        moc.refresh(self, mergeChanges: false)
                    }
                }
            }
        }
    }
}
#endif
