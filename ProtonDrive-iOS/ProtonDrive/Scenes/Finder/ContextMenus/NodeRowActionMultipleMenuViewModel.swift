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

struct NodeRowActionMultipleMenuViewModel: NodeRowActionMenuViewModelTrashAlertPresenting {
    let nodes: [Node]
    let model: NodeEditionViewModel
    
    internal init(nodes: [Node], model: NodeEditionViewModel) {
        self.nodes = nodes
        self.model = model
    }

    enum MenuSectionType {
        case folder
        case file
        case mixed
    }

    var section: MenuSectionType {
        if nodes.allSatisfy({ $0 is File }) {
            return .file
        } else if nodes.allSatisfy({ $0 is Folder }) {
            return .folder
        } else {
            return .mixed
        }
    }
}
