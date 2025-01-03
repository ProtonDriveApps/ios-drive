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
import Combine
import PDCore
import PDUIComponents
import SwiftUI
import PDLocalization

class NodeCellWithProgressConfiguration: ObservableObject, NodeCellConfiguration {
    @Published var node: Node
    @Published var progressCompleted: Double = 0
    let thumbnailViewModel: ThumbnailImageViewModel?
    var nodeRowActionMenuViewModel: NodeRowActionMenuViewModel?
    var uploadManagementMenuViewModel: UploadManagementMenuViewModel?
    private let nodeStatePolicy: NodeStatePolicy

    private var cancellables = Set<AnyCancellable>()
    private var progressCancellable: AnyCancellable?
    private var progressTracker: ProgressTracker?
    private var progressesAvailable: Bool
    private var progress: Progress? {
        self.progressTracker?.progress
    }

    let iconName: String
    var name: String
    var isFavorite: Bool { node.isFavorite }
    var isAvailableOffline: Bool { node.isAvailableOffline }
    var isShared: Bool { node.isShared }
    var hasSharing: Bool { featureFlagsController.hasSharing }
    var hasDirectShare: Bool { node.hasDirectShare }
    var lastModified: Date { node.modifiedDate }
    var size: Int { node.size }

    let progressDirection: ProgressTracker.Direction?
    let isDisabled = false
    let selectionModel: CellSelectionModel?
    let id: NodeIdentifier
    var featureFlagsController: FeatureFlagsControllerProtocol

    var actionButtonAction: () -> Void = { }
    var retryUploadAction: () -> Void = { }
    var cancelUploadAction: () -> Void = { }

    var isSharedWithMeRoot: Bool

    init(from node: Node,
         fileTypeAsset: FileTypeAsset = .shared,
         selectionModel: CellSelectionModel? = nil,
         progressesAvailable: Bool = false,
         progressTracker: ProgressTracker? = nil,
         downloadProgresses: [ProgressTracker] = [],
         thumbnailLoader: ThumbnailLoader,
         nodeStatePolicy: NodeStatePolicy,
         featureFlagsController: FeatureFlagsControllerProtocol,
         isSharedWithMeRoot: Bool
    ) {
        self.isSharedWithMeRoot = isSharedWithMeRoot
        self.progressesAvailable = progressesAvailable
        self.node = node
        self.selectionModel = selectionModel
        self.id = node.identifier
        self.name = node.decryptedName
        self.nodeStatePolicy = nodeStatePolicy

        self.iconName = fileTypeAsset.getAsset(node.mimeType)

        self.progressTracker = progressTracker
        self.progressDirection = progressTracker?.direction
        self.thumbnailViewModel = ThumbnailImageViewModel(node: node, loader: thumbnailLoader)
        self.featureFlagsController = featureFlagsController
        self.progressCancellable = progressTracker?.progressPublisher()?
            .receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.progressCompleted = $0
            }
    }

    private var file: File? {
        node as? File
    }

    private var thumbnail: Thumbnail? {
        file?.activeRevision?.thumbnails.first
    }

    var buttons: [NodeCellButton] {
        if self.uploadFailed || self.uploadWaiting || self.uploadPaused {
            return [.init(type: .cancel, action: self.cancelUploadAction),
                    .init(type: .retry, action: self.retryUploadAction)]
        } else {
            return [.init(type: .menu, action: self.actionButtonAction)]
        }
    }

    var isInProgress: Bool {
        self.progress?.isFinished == false && self.progress?.isCancelled == false
    }

    var uploadFailed: Bool {
        nodeStatePolicy.isUploadFailed(for: node, progressTracker: progressTracker, areProgressesAvailable: progressesAvailable)
    }

    var uploadWaiting: Bool {
        nodeStatePolicy.isUploadWaiting(for: node)
    }

    var uploadPaused: Bool {
        nodeStatePolicy.isUploadPaused(for: node)
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.multiplier = 100
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var secondLineSubtitle: String {
        switch self.progress {
        case _ where uploadPaused:
            return Localization.progress_status_paused
            
        case _ where uploadWaiting:
            return Localization.progress_status_waiting

        case .none where self.uploadFailed:
            return Localization.progress_status_upload_failed

        case .some where self.progressCompleted != 0 && self.isInProgress:
            if progressDirection == .upstream {
                return Localization.progress_status_uploaded(percent: percentageDownloaded)
            } else {
                return Localization.progress_status_downloaded(percent: percentageDownloaded)
            }
            
        case .some where self.isInProgress:
            return self.progressDirection == .upstream ? Localization.progress_status_uploading : Localization.progress_status_downloading

        case .some, .none:
            return self.isFolderDownloading ? Localization.progress_status_downloading : self.defaultSecondLineSubtitle
        }
    }

    var isFolderDownloading: Bool {
        (nodeType == .folder) && (node.isMarkedOfflineAvailable || node.isInheritingOfflineAvailable) && !node.isDownloaded
    }

    var percentageDownloaded: String {
        Self.percentFormatter.string(from: self.progressCompleted as NSNumber) ?? ""
    }

    var nodeType: NodeType {
        if node is Folder {
            return .folder
        } else {
            return .file
        }
    }

    var isSharedCollaboratively: Bool {
        node.isSharedWithMeRoot
    }

    var defaultSecondLineSubtitle: String {
        if isSharedWithMeRoot {
            return "\(inviter)•\(sharingDate)"
        } else {
            let suffix = "Modified \(DateStamper.stamp(for: self.lastModified))"
            if nodeType == .file && self.size > 0 {
                let sizeString = ByteCountFormatter.storageSizeString(forByteCount: Int64(self.size))
                return "\(sizeString), \(suffix)"
            } else {
                return suffix
            }
        }
    }

    var creator: String {
        inviter
    }

    private var inviter: String {
        node.directShares.first?.members.first?.inviter ?? ""
    }

    private var sharingDate: String {
        guard let membership = node.directShares.first?.members.first else { return "" }
        return DateFormatter.sharedWithMe.string(from: membership.modifyTime)
    }
}

extension DateFormatter {
    static let sharedWithMe = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter

    }()
}
