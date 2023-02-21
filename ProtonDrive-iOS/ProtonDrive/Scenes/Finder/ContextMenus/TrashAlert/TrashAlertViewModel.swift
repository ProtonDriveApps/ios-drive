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

final class TrashAlertViewModel {
    init(nodes: [Node], model: NodeEditionViewModel) {
        self.nodes = nodes
        self.model = model
    }
    
    convenience init(node: Node, model: NodeEditionViewModel) {
        self.init(nodes: [node], model: model)
    }

    let nodes: [Node]
    let model: NodeEditionViewModel

    var trashText: (title: String, button: String) {
        if nodes.count == 1, nodes.first is File {
            return ("Are you sure you want to move this file to Trash?", "Remove file")
        } else if nodes.count == 1, nodes.first is Folder {
            return ("Are you sure you want to move this folder to Trash?", "Remove folder")
        } else if nodes.allSatisfy({ $0 is File }) {
            return ("Are you sure you want to move \(nodes.count) files to Trash?", "Remove \(nodes.count) files")
        } else if nodes.allSatisfy({ $0 is Folder }) {
            return ("Are you sure you want to move \(nodes.count) folders to Trash?", "Remove \(nodes.count) folders")
        } else {
            return ("Are you sure you want to move \(nodes.count) items to Trash?", "Remove \(nodes.count) items")
        }
    }

    func trash(completion: @escaping (Result<Void, Error>) -> Void) {
        model.sendToTrash(nodes, completion: completion)
    }
}
