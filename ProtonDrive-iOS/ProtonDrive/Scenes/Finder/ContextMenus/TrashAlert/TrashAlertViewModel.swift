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
import PDLocalization

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
            return (Localization.action_trash_files_alert_message(num: 1), Localization.general_remove_files(num: 1))
        } else if nodes.count == 1, nodes.first is Folder {
            return (Localization.action_trash_folders_alert_message(num: 1), Localization.general_remove_folders(num: 1))
        } else if nodes.allSatisfy({ $0 is File }) {
            return (Localization.action_trash_files_alert_message(num: nodes.count), Localization.general_remove_files(num: nodes.count))
        } else if nodes.allSatisfy({ $0 is Folder }) {
            return (Localization.action_trash_folders_alert_message(num: nodes.count), Localization.general_remove_folders(num: nodes.count))
        } else {
            return (Localization.action_trash_items_alert_message(num: nodes.count), Localization.general_remove_items(num: nodes.count))
        }
    }

    func trash(completion: @escaping (Result<Void, Error>) -> Void) {
        model.sendToTrash(nodes, completion: completion)
    }
}

final class RemoveMeAlertViewModel {
    let node: Node
    let model: NodeEditionViewModel

    init(node: Node, model: NodeEditionViewModel) {
        self.node = node
        self.model = model
    }

    var removeMeTitle: String {
        Localization.shared_with_me_remove_me(item: node.decryptedName)
    }

    var itemName: String {
        node.decryptedName
    }

    var removeMeButton: String {
        Localization.shared_with_me_remove_me_confirmation
    }

    func removeMe(completion: @escaping (Result<Void, Error>) -> Void) {
        model.removeMe(node, completion: completion)
    }
}
