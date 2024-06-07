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
import Combine

final class TrashCellViewModel: ObservableObject {
    let node: Node
    var actionButtonAction: () -> Void = { }
    var restoreButtonAction: () -> Void = { }
    let selectionModel: CellSelectionModel?
    let iconName: String

    // MARK: Non-applicable for trash properties, required by `NodeCellConfiguration` protocol
    let isFavorite = false
    let isSavedForOffline = false
    let isDownloaded = false
    let isShared = false
    let isDisabled = false
    let uploadFailed = false
    let uploadWaiting = false
    var uploadPaused = false
    let isInProgress = false
    let progressCompleted: Double = 0
    let progressDirection: ProgressTracker.Direction? = nil
    let progress: Progress? = nil

    let thumbnailViewModel: ThumbnailImageViewModel?
    let nodeRowActionMenuViewModel: NodeRowActionMenuViewModel?
    
    init(node: Node,
         fileTypeAsset: FileTypeAsset = .shared,
         selectionModel: CellSelectionModel? = nil,
         nodeRowActionMenuViewModel: NodeRowActionMenuViewModel? = nil)
    {
        self.node = node
        self.selectionModel = selectionModel
        self.thumbnailViewModel = ThumbnailImageViewModel(node: node)
        self.nodeRowActionMenuViewModel = nodeRowActionMenuViewModel
        self.iconName = fileTypeAsset.getAsset(node.mimeType)
    }
}

extension TrashCellViewModel: NodeCellConfiguration {
    var id: NodeIdentifier {
        node.identifier
    }
    
    var name: String {
        node.decryptedName
    }

    var lastModified: Date {
        node.modifiedDate
    }
    
    var size: Int {
        node.size
    }
    
    var secondLineSubtitle: String  {
        defaultSecondLineSubtitle
    }
    var buttons: [NodeCellButton] {
        [NodeCellButton(type: .trash(id: id), action: {})]
    }

    var nodeID: String {
        node.id
    }

    var isFolder: Bool {
        node is Folder ? true : false
    }

    var nodeType: NodeType {
        if node is Folder {
            return .folder
        } else {
            return .file
        }
    }

    func onTap() {
        isSelecting ? selectionModel?.onTap(id: node.identifier) : ()
    }

    func onLongPress() {
        selectionModel?.onLongPress()
    }
}
