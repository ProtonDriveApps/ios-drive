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
import Foundation

final class EditNodeModel {
    private var tower: Tower
    
    init(tower: Tower) {
        self.tower = tower
    }
}

extension EditNodeModel: FolderCreator {
    func createFolder(with name: String, parent: Folder, completion: @escaping (FolderCreator.Result) -> Void) {
        if let performer = tower.sdkObjects.nodeOperationPerformer {
            Task.detached {
                let parentID = parent.identifier.any()
                do {
                    let folder = try await performer.createFolder(parentFolderID: parentID, name: name)
                    completion(.success(folder))
                } catch {
                    completion(.failure(error))
                }
            }
        } else {
            self.tower.createFolder(named: name, under: parent, moc: tower.storage.backgroundContext, handler: completion)
        }
    }
}

extension EditNodeModel: NodeNameEditorProtocol {
    func rename(to name: String, node: NodeIdentifier, completion: @escaping (NodeNameEditorProtocol.Result) -> Void) {
        if let performer = tower.sdkObjects.nodeOperationPerformer {
            Task {
                do {
                    let node = try await performer.rename(nodeUid: node.any(), newName: name)
                    completion(.success(node))
                } catch {
                    completion(.failure(error))
                }
            }
        } else {
            tower.rename(node: node, cleartextName: name, moc: tower.storage.backgroundContext, handler: completion)
        }
    }
}
