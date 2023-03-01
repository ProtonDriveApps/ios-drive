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
import Combine
import PDUIComponents

class NodeCellPlaceholderConfiguration: ObservableObject, NodeCellConfiguration {

    var iconName: String
    var name: String
    var isFavorite: Bool = false
    var isSavedForOffline: Bool = false
    var isDownloaded: Bool = false
    var isShared: Bool = false
    var lastModified: Date = .distantPast
    var size: Int = 0
    var isDisabled: Bool = true
    var buttons: [NodeCellButton] = []
    var uploadFailed: Bool = false
    var uploadWaiting: Bool = false
    var uploadPaused: Bool = false
    var isInProgress: Bool = false
    let progressCompleted: Double = 0
    var progressDirection: ProgressTracker.Direction?
    var secondLineSubtitle: String { "Unknown" }
    var selectionModel: CellSelectionModel?
    var id: String = ""
    
    let thumbnailViewModel: ThumbnailImageViewModel?
    let nodeRowActionMenuViewModel: NodeRowActionMenuViewModel? = nil

    init() {
        self.iconName = FileTypeAsset.FileAssetName.unknown.rawValue
        self.name = Self.unknownNamePlaceholder
        self.thumbnailViewModel = nil
    }

    var nodeType: NodeType { .mix }
}
