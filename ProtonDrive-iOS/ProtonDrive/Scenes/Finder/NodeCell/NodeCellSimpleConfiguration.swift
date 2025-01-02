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
import Combine
import PDUIComponents
import SwiftUI

class NodeCellSimpleConfiguration: ObservableObject, NodeCellConfiguration {
    
    var iconName: String
    var name: String
    var isFavorite: Bool
    var isAvailableOffline: Bool
    var isShared: Bool
    var hasSharing: Bool
    var hasDirectShare: Bool
    var isSharedWithMeRoot: Bool = false
    var isSharedCollaboratively: Bool
    var creator: String = ""
    var lastModified: Date
    var isDisabled: Bool
    var size: Int
    
    var buttons: [NodeCellButton] = []
    var uploadFailed: Bool = false
    var uploadWaiting: Bool = false
    var uploadPaused: Bool = false
    var isInProgress: Bool = false
    let progressCompleted: Double = 0
    var progressDirection: ProgressTracker.Direction?
    let selectionModel: CellSelectionModel? = nil
    let id: NodeIdentifier

    let thumbnailViewModel: ThumbnailImageViewModel?
    let nodeRowActionMenuViewModel: NodeRowActionMenuViewModel? = nil
    let featureFlagsController: FeatureFlagsControllerProtocol

    init(
        from node: Node,
        fileTypeAsset: FileTypeAsset = .shared,
        disabled: Bool,
        loader: ThumbnailLoader,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) {
        self.iconName = fileTypeAsset.getAsset(node.mimeType)
        self.name = node.decryptedName
        self.isFavorite = node.isFavorite
        self.isAvailableOffline = node.isAvailableOffline
        self.isShared = node.isShared
        self.hasDirectShare = node.hasDirectShare
        self.isSharedCollaboratively = node.isSharedWithMeRoot
        self.lastModified = node.modifiedDate
        self.size = node.size
        self.isDisabled = disabled
        self.id = node.identifier
        self.thumbnailViewModel = ThumbnailImageViewModel(node: node, loader: loader)
        self.featureFlagsController = featureFlagsController
        self.hasSharing = featureFlagsController.hasSharing
    }
    
    var secondLineSubtitle: String { self.defaultSecondLineSubtitle }
    var nodeType: NodeType { .mix }
}
