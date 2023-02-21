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

import Foundation
import PDCore
import PDUIComponents

extension FinderCoordinator {
    enum Destination: Identifiable, Hashable {
        case none // no changes to hierarchy

        case file(file: File, share: Bool), folder(Folder) // push to navigation controller
        
        case importPhoto, importDocument, camera // modals
        case nodeDetails(Node)
        case createFolder(parent: Folder), rename(Node), move([Node], parent: Folder?)
        case shareLink(node: Node)
        case shareIn(url: URL)
        
        case noSpaceLeftLocally, noSpaceLeftCloud
    }
    
    func destination(for nextNode: Node) -> Destination {
        switch nextNode {
        case is File where self.model is MoveModel:
            return .none

        case is Folder where (self.model as? MoveModel)?.nodeIdsToMove.contains(nextNode.identifier) == true:
            return .none

        case is File where (nextNode as? File)?.activeRevision?.blocksAreValid() == true: // cached file
            return .file(file: nextNode as! File, share: false)

        case is File: // only metadata is locally available
            return .none

        case is Folder:
            return .folder(nextNode as! Folder)

        default:
            assert(false, "Unknown type of node")
            return .none
        }
    }
}

extension FinderCoordinator.Destination: MirrorableEnum {
    var id: String {
        mirror.label
    }
}
