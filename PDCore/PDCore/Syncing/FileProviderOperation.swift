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

public enum FileProviderOperation: Int, Codable, CaseIterable {
    /// Undefined is default value
    case undefined        // 0
    case create           // 1
    case update           // 2
    case delete           // 3
    case fetchContents    // 4
    case fetchItem        // 5
    /// Use case: "Force refresh" action or navigating to a directory in Finder
    case enumerateItems   // 6
    /// Use case: Detecting remote changes
    case enumerateChanges // 7
    case move             // 8
    case rename           // 9
    case remoteCreate     // 10
    case remoteTrash      // 11
}

extension FileProviderOperation {
    /// NSFileProvider collectively refers to updates, moves and renames as modifications.
    /// We break them down into separate cases, but still want to know whether a given operation is a type of modification.
    public var isModification: Bool {
        switch self {
        case .update, .move, .rename:
            true
        default:
            false
        }
    }

    public var isSizeAgnostic: Bool {
        switch self {
        case .move, .rename, .delete:
            true
        default:
            false
        }
    }

    public var operationDescriptionWhenQueued: String {
        let operationName = switch self {
        case .create:
            " to upload"
        case .undefined:
            ""
        case .update:
            " to be updated"
        case .delete:
            " to be deleted"
        case .fetchContents:
            " to download"
        case .fetchItem:
            " to download"
        case .enumerateItems:
            " for file listing"
        case .enumerateChanges, .remoteCreate, .remoteTrash:
            " for change listing"
        case .rename:
            " to be renamed"
        case .move:
            " to be moved"
        }

        return "Waiting" + operationName
    }

    public var operationDescriptionWhenInProgress: String {
        switch self {
        case .create:
            "Uploading"
        case .undefined:
            "Undefined"
        case .update:
            "Updating"
        case .delete:
            "Deleting"
        case .fetchContents:
            "Downloading"
        case .fetchItem:
            "Downloading"
        case .enumerateItems:
            "Fetching file list"
        case .enumerateChanges, .remoteCreate, .remoteTrash:
            "Fetching updates"
        case .rename:
            "Renaming"
        case .move:
            "Moving"
        }
    }

    public var operationDescriptionWhenCompleted: String {
        return switch self {
        case .create:
            "Uploaded"
        case .undefined:
            "Undefined"
        case .update:
            "Modified"
        case .delete:
            "Deleted"
        case .fetchContents:
            "Downloaded"
        case .fetchItem:
            "Downloaded"
        case .enumerateItems:
            "Listed"
        case .enumerateChanges:
            "Updated online"
        case .rename:
            "Renamed"
        case .move:
            "Moved"
        case .remoteCreate:
            "Created online"
        case .remoteTrash:
            "Deleted online"
        }
    }
}

public extension FileProviderOperation {
    var descriptionForLogs: String {
        switch self {
        case .fetchItem: return "fetchItem"
        case .fetchContents: return "fetchContents"
        case .create: return "createItem"
        case .update: return "modifyItem(update)"
        case .move: return "modifyItem(move)"
        case .rename: return "modifyItem(rename)"
        case .delete: return "deleteItem"
        case .enumerateChanges: return "enumerateChanges"
        case .enumerateItems: return "enumerateItems"
        case .undefined: return "undefined"
        case .remoteCreate: return "remoteCreateItem"
        case .remoteTrash: return "remoteTrashItem"
        }
    }
}
