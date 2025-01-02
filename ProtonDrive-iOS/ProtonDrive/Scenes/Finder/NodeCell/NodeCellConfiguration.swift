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

extension NodeCellButton.ActionButtonType: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}

struct NodeCellButton: Hashable {
    let type: ActionButtonType
    let action: () -> Void

    enum ActionButtonType: Hashable {
        case menu
        case trash(id: NodeIdentifier)
        case cancel
        case retry
    }

    static func == (lhs: NodeCellButton, rhs: NodeCellButton) -> Bool {
        lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }
}

protocol NodeCellConfiguration: AnyObject {
    var nodeType: NodeType { get }
    var iconName: String { get }
    var name: String { get }
    var isFavorite: Bool { get }
    var isAvailableOffline: Bool { get }
    /// Public share link has been enabled
    var isShared: Bool { get }
    // Sharing feature is enabled
    var hasSharing: Bool { get }
    var hasDirectShare: Bool { get }
    var isSharedWithMeRoot: Bool { get }
    var isSharedCollaboratively: Bool { get }
    var lastModified: Date { get }
    var size: Int { get }
    var secondLineSubtitle: String { get }
    var isDisabled: Bool { get }
    var creator: String { get }

    var buttons: [NodeCellButton] { get }
    
    var uploadFailed: Bool { get }
    var uploadWaiting: Bool { get }
    var uploadPaused: Bool { get }
    
    var isInProgress: Bool { get }
    var progressCompleted: Double { get }
    var progressDirection: ProgressTracker.Direction? { get }
    var selectionModel: CellSelectionModel? { get }
    var id: NodeIdentifier { get }

    var thumbnailViewModel: ThumbnailImageViewModel? { get }
    
    var nodeRowActionMenuViewModel: NodeRowActionMenuViewModel? { get }
    var featureFlagsController: FeatureFlagsControllerProtocol { get }
    var defaultSecondLineSubtitle: String { get }
}

extension NodeCellConfiguration {
    static var unknownNamePlaceholder: String {
        String.randomPlaceholder
    }

    var defaultSecondLineSubtitle: String {
        let suffix = "Modified \(DateStamper.stamp(for: self.lastModified))"
        if nodeType == .file && self.size > 0 {
            let sizeString = ByteCountFormatter.storageSizeString(forByteCount: Int64(self.size))
            return "\(sizeString), \(suffix)"
        } else {
            return suffix
        }
    }
}
