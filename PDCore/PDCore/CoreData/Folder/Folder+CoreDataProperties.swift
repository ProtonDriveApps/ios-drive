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

import Foundation
import CoreData

extension Folder {
    public static let mimeType = "Folder"

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }

    @NSManaged public var nodeHashKey: String?
    @NSManaged public var children: Set<Node>
    @NSManaged public var isChildrenListFullyFetched: Bool

    public var isRoot: Bool {
        self.directShares.contains(where: \.isMain)
    }

    public var isDeviceRoot: Bool {
        self.primaryDirectShare?.type == .device
    }
}

// MARK: Generated accessors for children
extension Folder {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Node)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Node)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: Set<Node>)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: Set<Node>)

}

extension Folder {
    @objc public func isolateChildrenToPreventCascadeDeletion() {
        let children = self.children

        for child in children {
            if child.isSharedWithMeRoot {
                self.removeFromChildren(child)
                child.parentFolder = nil
            } else if let childFolder = child as? Folder {
                childFolder.isolateChildrenToPreventCascadeDeletion()
            }
        }
    }
}
