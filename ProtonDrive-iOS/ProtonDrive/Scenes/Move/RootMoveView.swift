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
import PDCore
import PDUIComponents

struct RootMoveView: View {
    @EnvironmentObject var externalRoot: RootViewModel // this is root of the parent hierarchy
    @State var createFolderIn: Folder?
    @State var internalRoot = RootViewModel()// this is root inside the modal hierarchy
    
    var coordinator: FinderCoordinator
    var nodes: [NodeIdentifier]
    var root: NodeIdentifier
    var parent: NodeIdentifier
    
    var body: some View {
        RootDeeplinkableView(navigationTracker: self.coordinator) {
            self.coordinator.start(.move(rootNode: self.root, nodesToMove: self.nodes, nodeToMoveParent: self.parent))
        }
        .overlay(
            ActionBar(onSelection: actionBarAction,
                      leadingItems: [.cancel],
                      trailingItems: [.createFolder])
        )
        .presentView(item: $createFolderIn, style: .sheet) {
            coordinator.go(to: .createFolder(parent: $0)).environmentObject(internalRoot)
        }
    }
    
    func actionBarAction(_ selected: ActionBarButtonViewModel?) {
        switch selected {
        case .createFolder:
            self.createFolderIn = self.coordinator.topmostDescendant?.model?.folder ?? self.coordinator.model?.folder
        case .cancel:
            self.externalRoot.closeCurrentSheet.send()
            
        default: break
        }
    }
}
