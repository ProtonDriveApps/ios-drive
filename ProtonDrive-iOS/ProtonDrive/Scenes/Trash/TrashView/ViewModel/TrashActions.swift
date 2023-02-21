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

import SwiftUI
import PDCore

enum NodeOperationType {
    case single(id: String, type: NodeType)
    case multiple(ids: [String], type: NodeType)
    case all(ids: [String], type: NodeType)

    var itemID: String? {
        switch self {
        case .single(let id, _):
            return id
        case .all:
            return nil
        case .multiple:
            fatalError()
        }
    }

    var restoreText: String {
        switch self {
        case .single(_, let nodetype):
            return "Restore \(nodetype.type)"
        case .all(let ids, let nodetype):
            let begining = ids.count > 1 ? "Restore all" : "Restore"
            return "\(begining) \(nodetype.type)\(ids.ending)"
        case .multiple(let ids, let nodetype):
            return "Restore selected \(nodetype.type)\(ids.ending)"
        }
    }

    var deleteText: String {
        switch self {
        case .single:
            return "Delete"
        case .all:
            return "Empty Trash"
        case .multiple:
            return "Delete"
        }
    }

    var deleteConfirmationTitle: String {
        switch self {
        case .single(_, let nodetype):
            return "\(nodetype.rawValue) will be deleted permanently. \nDelete anyway?"
        case .all(let ids, let nodetype):
            return manyConfirmationTitle(ids: ids, type: nodetype)
        case .multiple(let ids, let nodetype):
            return manyConfirmationTitle(ids: ids, type: nodetype)
        }
    }

    private func manyConfirmationTitle(ids: [String], type: NodeType) -> String {
        "\(type.rawValue)\(ids.ending) will be deleted permanently. \nDelete anyway?"
    }

    var deleteConfirmationButtonText: String {
        switch self {
        case .single(_, let nodetype):
            return "Delete \(nodetype.type)"
        case .all(let ids, let nodetype):
            return manyDeletionButtonText(ids: ids, type: nodetype)
        case .multiple(let ids, let nodetype):
            return manyDeletionButtonText(ids: ids, type: nodetype)
        }
    }

    private func manyDeletionButtonText(ids: [String], type: NodeType) -> String {
        "Delete \(ids.count) \(type.type)" + ids.ending
    }
}

enum TrashItemAction {
    case delete
    case restore
}

private extension Array where Element == String {
    var ending: String {
        count > 1 ? "s" : ""
    }
}
