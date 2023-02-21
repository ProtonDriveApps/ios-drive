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

struct NodeRowActionMenuViewModel {
    let node: Node
    let model: NodeEditionViewModel
    let isNavigationMenu: Bool

    internal init(node: Node, model: NodeEditionViewModel, isNavigationMenu: Bool = false) {
        self.node = node
        self.model = model
        self.isNavigationMenu = isNavigationMenu
    }

    enum MenuSectionType {
        case folder
        case file
    }

    var section: MenuSectionType {
        if node is File {
            return .file
        } else if node is Folder {
            return .folder
        } else {
            fatalError("This case should not be possible")
        }
    }

    var title: String {
        node.decryptedName
    }

    var subtitle: String? {
        NodeDetailsViewModel.subtitle(for: node)
    }
}

extension NodeRowActionMenuViewModel: NodeRowActionMenuViewModelTrashAlertPresenting {
    var nodes: [Node] {
        [node]
    }
}
