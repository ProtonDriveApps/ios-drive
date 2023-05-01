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
    case modifyContents(contents: URL?)
    case move(fields: NSFileProviderItemFields)
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
            case .move(let fields):
                return conflictOnMove(tower: tower, item: item, changedFields: fields, request: request)
            case .modifyMetadata(let fields):
                return conflictOnMetadata(tower: tower, item: item, changedFields: fields, request: request)
            case .modifyContents(let contentURL):
                return conflictOnContents(tower: tower, item: item, contents: contentURL, request: request)
            case .delete:
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

    private func conflictOnMove(tower: Tower, item: NSFileProviderItem, changedFields: NSFileProviderItemFields, request: NSFileProviderRequest?) -> (ConflictingOperation?, Node?) {
        let nodes = tower.retrieveNodes(basedOn: item)
        if changedFields.contains(.filename) && changedFields.contains(.parentItemIdentifier) {
            // Subject to conflict on move
            let eligibleNode = nodes.first(
                where: {
                    let nodeItem = NodeItem(node: $0)
                    return $0.decryptedName == item.filename && item.contentType == nodeItem.contentType
                }
            )
            return (.move(.edit(nil)), eligibleNode)
        }
        return (nil, nil)
    }

    private func conflictOnContents(tower: Tower, item: NSFileProviderItem, contents newContent: URL?, request: NSFileProviderRequest?) -> (ConflictingOperation?, Node?) {
        let nodes = tower.retrieveNodes(basedOn: item)
        if newContent == nil, item.isFolder {
            return (nil, nil)
        }
        if item.parentItemIdentifier == .trashContainer,
            let node = tower.node(itemIdentifier: item.itemIdentifier) {
            return (.edit(.delete(parent: false)), node)
        }
        if tower.node(itemIdentifier: item.itemIdentifier) == nil {
            if let parentNode = tower.node(itemIdentifier: item.parentItemIdentifier), parentNode.state == .deleted {
                return (.edit(.delete(parent: true)), nil)
            }
            return (.edit(.delete(parent: false)), nil)
        }

        if let eligibleNode = nodes.first(
            where: {
                let nodeItem = NodeItem(node: $0)
                return $0.decryptedName == item.filename &&
                item.contentType == nodeItem.contentType &&
                nodeItem.contentModificationDate != item.contentModificationDate
            }
        ) {
            return (.edit(.edit(nil)), eligibleNode)
        }
        return (nil, nil)
    }

    private func conflictOnMetadata(tower: Tower, item: NSFileProviderItem, changedFields: NSFileProviderItemFields, request: NSFileProviderRequest?) -> (ConflictingOperation?, Node?) {
        let nodes = tower.retrieveNodes(basedOn: item)
        if changedFields.contains(.filename) && changedFields.contains(.parentItemIdentifier) {
            return (nil, nil)
        }
        if changedFields.contains(.filename) {
            if let eligibleNode = nodes.first(
                where: {
                    let nodeItem = NodeItem(node: $0)
                    return $0.decryptedName == item.filename && item.contentType == nodeItem.contentType
                }
            ) {
                // Subject to conflict on move
                return (.edit(.move(nil)), eligibleNode)
            } else {
                return (nil, nil)
            }
        } else {
            return (nil, nil)
        }
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
