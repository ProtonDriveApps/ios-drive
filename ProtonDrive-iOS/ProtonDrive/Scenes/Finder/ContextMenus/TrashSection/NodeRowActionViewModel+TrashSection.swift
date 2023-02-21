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

import PDCore
import SwiftUI
import ProtonCore_UIFoundations
import PDUIComponents

enum TrashSectionItem: SectionItemDisplayable {

    case restore(type: NodeOperationType)
    case delete(type: NodeOperationType)

    var text: String {
        switch self {
        case .restore(let type):
            return type.restoreText
        case .delete(let type):
            return type.deleteText
        }
    }

    var identifier: String {
        let name: String
        switch self {
        case .restore: name = "restore"
        case .delete: name = "delete"
        }
        return "TrashSectionItem.\(name)"
    }

    var icon: Image {
        switch self {
        case .restore: return IconProvider.arrowsRotate
        case .delete: return IconProvider.trash
        }
    }
}

extension TrashViewModel {

    func trashSectionItems(type: NodeOperationType, action: @escaping () -> Void) -> [ContextMenuItem] {
        [restoreRow(type: type), deleteRow(type: type, action: action)]
    }

    private func restoreRow(type: NodeOperationType) -> ContextMenuItem {
        ContextMenuItem(sectionItem: TrashSectionItem.restore(type: type), role: .default) {
            switch type {
            case .single(let id, _):
                self.restore(nodes: [id], completion: {})
            case .all:
                self.restore(nodes: Array(self.selection.selectable), completion: {})
            case .multiple:
                self.restore(nodes: Array(self.selection.selected), completion: {})
            }
        }
    }

    private func deleteRow(type: NodeOperationType, action: @escaping () -> Void) -> ContextMenuItem {
        ContextMenuItem(
            sectionItem: TrashSectionItem.delete(type: type),
            role: .destructive,
            handler: action
        )
    }

}

extension TrashCellViewModel {

    func restoreRow(type: NodeOperationType, action: @escaping () -> Void) -> ContextMenuItem {
        ContextMenuItem(
            sectionItem: TrashSectionItem.restore(type: type),
            handler: action
        )
    }

    func deleteRow(type: NodeOperationType, action: @escaping () -> Void) -> ContextMenuItem {
        ContextMenuItem(
            sectionItem: TrashSectionItem.delete(type: type),
            role: .destructive,
            handler: action
        )
    }

}
