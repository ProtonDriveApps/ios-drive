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

struct RootFolderView: View {
    let nodeID: NodeIdentifier
    let coordinator: FinderCoordinator
    
    init(nodeID: NodeIdentifier, coordinator: FinderCoordinator) {
        self.nodeID = nodeID
        self.coordinator = coordinator
    }
    
    var body: some View {
        RootDeeplinkableView(navigationTracker: coordinator) {
            coordinator.start(.folder(nodeID: nodeID))
        }
    }
}

class MyFilesRootFetcher {
    let storage: StorageManager

    init(storage: StorageManager) {
        self.storage = storage
    }

    func getRoot() -> NodeIdentifier {
        return storage.mainContext.performAndWait {
            let shares = storage.getMainShares(in: storage.mainContext)
            guard let share = shares.first,
                  let linkID = share.linkID else {
                NotificationCenter.default.post(name: .nukeCache)
                return NodeIdentifier("", "", "")
            }
            return NodeIdentifier(linkID, share.id, share.volumeID)
        }
    }
}
