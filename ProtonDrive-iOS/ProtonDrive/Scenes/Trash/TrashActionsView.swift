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
import PMUIFoundations

enum NodeDeletionType {
    case single(id: String, type: TrashNodeSelectionType)
    case all(count: Int, type: TrashNodeSelectionType)

    var itemID: String? {
        switch self {
        case .single(let id, _):
            return id
        case .all:
            return nil
        }
    }

    var restoreText: String {
        switch self {
        case .single(_, let nodetype):
            return "Restore \(nodetype.type)"
        case .all(_, let nodetype):
            return "Restore all \(nodetype.type)s"
        }
    }

    var deleteText: String {
        switch self {
        case .single:
            return "Delete"
        case .all:
            return "Empty Trash"
        }
    }

    var deleteConfirmationTitle: String {
        switch self {
        case .single(_, let nodetype):
            return "\(nodetype.rawValue) will be deleted permanently. \nDelete anyway?"
        case .all(let count, let nodetype):
            let ending = count > 1 ? "s" : ""
            return "\(nodetype.rawValue)\(ending) will be deleted permanently. \nDelete anyway?"
        }
    }

    var deleteConfirmationButtonText: String {
        switch self {
        case .single(_, let nodetype):
            return "Delete \(nodetype.type)"
        case .all(let count, let nodetype):
            let ending = count > 1 ? "s" : ""
            return "Delete \(count) \(nodetype.type)" + ending
        }
    }
}

enum TrashNodeSelectionType: String {
    case file = "File"
    case folder = "Folder"
    case mix = "Item"

    var type: String {
        rawValue.lowercased()
    }
}

enum TrashItemAction {
    case delete
    case restore
}

enum TrashViewActionState: Equatable {
    case initial
    case beginDeletion
}

struct TrashActionsView: View {
    @State private var state: TrashViewActionState = .initial
    let type: NodeDeletionType
    let action: (TrashItemAction) -> Void
    let dismiss: () -> Void
    let errorStream: ErrorToastModifier.Stream

    var body: some View {
        VStack {
            if state == .initial {
                PartialSheetMenuSection(cancel: {
                    self.dismiss()
                }, contents: {
                    Group {
                        PartialSheetMenuItem(
                            image: Image("trashArrowUp"),
                            title: type.restoreText) {
                                self.action(.restore)
                        }

                        PartialSheetMenuItem(
                            image: Image("trash"),
                            title: type.deleteText, primaryColor: FunctionalColors.Red) {
                                self.state = .beginDeletion
                        }
                    }
                })
            }

            if state == .beginDeletion {
                DeleteItemConfirmationView(title: type.deleteConfirmationTitle,
                                           button: type.deleteConfirmationButtonText) { action in
                    switch action {
                    case .delete:
                        self.action(.delete)
                    case .cancel:
                        self.dismiss()
                    }
                }
                .errorToast(location: .bottom, errors: errorStream)
            }
        }
        .offset(y: -20)
        .frame(height: 200)
    }
}
