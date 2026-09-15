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
import PDCoreIOS
import PDSDKCore

struct NameEditingNode {
    let id: NodeIdentifier
    let fullName: String
    let type: NodeType

    init(id: NodeIdentifier, decryptedName: String, type: NameEditingNode.NodeType) {
        self.id = id
        self.fullName = decryptedName
        self.type = type
    }

    enum NodeType {
        case folder
        case file
        case computer
    }
}

extension NameEditingNode {
    init(node: Node) {
        self.init(id: NodeIdentifier(node.id, node.shareId, node.volumeID),
                  decryptedName: node.decryptedName,
                  type: (node is Folder) ? .folder : .file)
    }
    
    init(node: NodeDTO) {
        self.init(
            id: node.nodeIdentifier,
            decryptedName: node.name,
            type: node.isFile ? .file : .folder
        )
    }

    init(computer: ComputerIdentifier, name: String) {
        self.init(id: NodeIdentifier(computer.nodeID, computer.shareID, computer.volumeID), decryptedName: name, type: .computer)
    }
}
