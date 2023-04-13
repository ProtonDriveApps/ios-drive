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

public enum ItemActionChangeType {
    case create
    case modifyMetadata(fields: NSFileProviderItemFields)
    case modifyContent(content: URL)
    case move
    case delete
}

extension ItemActionsOutlet: ConflictDetection {

    public func identifyConflict(
        tower: Tower,
        basedOn item: NSFileProviderItem,
        changeType: ItemActionChangeType,
        request: NSFileProviderRequest?) -> (ConflictingOperation?, Node?) {

            switch changeType {
            case .create:
                return conflictOnCreate(tower: tower, item: item, request: request)
            case .move, .delete, .modifyContent, .modifyMetadata:
                return (nil, nil)
            }
    }

    private func conflictOnCreate(tower: Tower, item: NSFileProviderItem, request: NSFileProviderRequest?) -> (ConflictingOperation?, Node?) {
        if item.isFolder {
            let folders = tower.retrieveNodes(basedOn: item).compactMap { $0 as? Folder }
            // Looking for a conflicting folder
            // Only deal with one conflict at a time
            // Creating a file with the same name under the same parent on both replicas. File Extension resolve the content differences by itself
            if let conflictedFolder = folders.first(
                where: {
                    guard let parentLink = $0.parentLink,
                          let parentItemIdentifier = tower.parentFolder(of: item)?.id else {
                        return false
                    }
                    return $0.decryptedName == item.filename && parentLink.id == parentItemIdentifier
                }
            ) {
                return (.create(nil), conflictedFolder)
            }
        }
        return (nil, nil)
    }

    private func conflictOnModify(tower: Tower, item: NSFileProviderItem, request: NSFileProviderRequest?) -> ConflictingOperation? {
        // DRIVIOS tickets on edit
        return nil
    }

}

// MARK: - Resolution

extension ItemActionsOutlet: ConflictResolution {

    public func resolveConflictOnItemIfNeeded(
        tower: Tower, item: NSFileProviderItem, changeType: ItemActionChangeType,
        request: NSFileProviderRequest?) -> (NSFileProviderItem, Bool) {
            if #available(macOS 12.0, *) {
                let (conflictOperation, node) = identifyConflict(tower: tower, basedOn: item, changeType: changeType, request: request)
                guard let operation = conflictOperation,
                        let node = node else {
                    return (item, false)
                }
                do {
                    let conflictStrategy = try tower.conflictStrategy(for: item, operation)
                    return tower.resolveConflict(on: node, with: conflictStrategy)
                } catch {
                    ConsoleLogger.shared?.log("Could not determine conflictStrategy", osLogType: Self.self)
                    return (item, false)
                }
            }
            return (item, false)

    }

}
