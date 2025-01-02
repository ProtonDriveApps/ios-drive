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

final class EditNodeModel {
    private var tower: Tower
    
    init(tower: Tower) {
        self.tower = tower
    }
}

extension EditNodeModel: FolderCreator {
    func createFolder(with name: String, parent: Folder, completion: @escaping (FolderCreator.Result) -> Void) {
        self.tower.createFolder(named: name, under: parent, handler: completion)
    }
}

extension EditNodeModel: NodeNameEditorProtocol {
    func rename(to name: String, node: NodeIdentifier, completion: @escaping (NodeNameEditorProtocol.Result) -> Void) {
        tower.rename(node: node, cleartextName: name, handler: completion)
    }
}
