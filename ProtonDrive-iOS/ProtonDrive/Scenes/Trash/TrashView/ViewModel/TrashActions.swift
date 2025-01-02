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
import PDLocalization

enum NodeOperationType {
    case single(id: NodeIdentifier, type: NodeType)
    case multiple(ids: [NodeIdentifier], type: NodeType)
    case all(ids: [NodeIdentifier], type: NodeType)

    var itemID: NodeIdentifier? {
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
        case .single(_, let nodeType):
            return Localization.trash_action_restore(type: nodeType.type)
        case .all(let ids, let nodeType):
            if ids.count > 1 {
                return nodeType.restoreAllText
            } else {
                return Localization.trash_action_restore(type: nodeType.type)
            }
        case .multiple(let ids, let nodeType):
            let type = nodeType.pluralTypesWith(count: ids.count)
            return Localization.trash_action_restore_selected(type: type)
        }
    }

    var deleteText: String {
        switch self {
        case .single:
            return Localization.general_delete
        case .all:
            return Localization.trash_action_empty_trash
        case .multiple:
            return Localization.general_delete
        }
    }

    var deleteConfirmationTitle: String {
        switch self {
        case .single(_, let nodeType):
            let type = nodeType.type.capitalized
            return Localization.trash_action_delete_permanently_confirmation_title(type: type)
        case .all(let ids, let nodeType):
            let type = nodeType.pluralTypesWith(count: ids.count)
            return Localization.trash_action_delete_permanently_confirmation_title(type: type)
        case .multiple(let ids, let nodeType):
            let type = nodeType.pluralTypesWith(count: ids.count)
            return Localization.trash_action_delete_permanently_confirmation_title(type: type)
        }
    }

    var deleteConfirmationButtonText: String {
        switch self {
        case .single(_, let nodeType):
            let type = nodeType.type
            return Localization.trash_action_delete_file_button(type: type)
        case .all(let ids, let nodeType):
            let type = nodeType.pluralTypesWith(count: ids.count)
            return Localization.trash_action_delete_file_button(type: type)
        case .multiple(let ids, let nodeType):
            let type = nodeType.pluralTypesWith(count: ids.count)
            return Localization.trash_action_delete_file_button(type: type)
        }
    }
}

enum TrashItemAction {
    case delete
    case restore
}
