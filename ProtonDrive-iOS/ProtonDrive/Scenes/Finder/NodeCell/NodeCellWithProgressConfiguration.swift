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

class NodeCellWithProgressConfiguration: ObservableObject, NodeCellConfiguration {
    @Published var node: Node
    @Published var progressCompleted: Double = 0
    let thumbnailViewModel: ThumbnailImageViewModel?
    var nodeRowActionMenuViewModel: NodeRowActionMenuViewModel?
    var uploadManagementMenuViewModel: UploadManagementMenuViewModel?

    private var cancellables = Set<AnyCancellable>()
    private var progressCancellable: AnyCancellable?
    private var progressTracker: ProgressTracker?
    private var progressesAvailable: Bool
    private var progress: Progress? {
        self.progressTracker?.progress
    }
    
    var state: Node.State { node.state ?? .active }
    let iconName: String
    var name: String
    var isFavorite: Bool { node.isFavorite }
    var isSavedForOffline: Bool { node.isMarkedOfflineAvailable || node.isInheritingOfflineAvailable }
    var isDownloaded: Bool { node.isDownloaded }
    var isShared: Bool { node.isShared }
    var lastModified: Date { node.modifiedDate }
    var size: Int { node.size }
    
    let progressDirection: ProgressTracker.Direction?
    let isDisabled = false
    let selectionModel: CellSelectionModel?
    let id: String
    
    var actionButtonAction: () -> Void = { }
    var retryUploadAction: () -> Void = { }
    var cancelUploadAction: () -> Void = { }
    
    init(from node: Node,
         fileTypeAsset: FileTypeAsset = .shared,
         selectionModel: CellSelectionModel? = nil,
         uploadProgresses: [UUID: Progress]? = [:],
         downloadProgresses: [ProgressTracker] = [],
         thumbnailLoader: ThumbnailLoader)
    {
        self.progressesAvailable = uploadProgresses != nil
        self.node = node
        self.selectionModel = selectionModel
        self.id = node.id
        self.name = node.decryptedName

        self.iconName = fileTypeAsset.getAsset(node.mimeType)

        var progressPack: ProgressTracker?
        if let file = node as? File {
            if let uploadID = file.uploadID,
               let uploadProgress = uploadProgresses?[uploadID],
               file.activeRevisionDraft != nil {
                progressPack = ProgressTracker(progress: uploadProgress, direction: .upstream)
            } else {
                progressPack = downloadProgresses.first { $0.matches(file.id) }
            }
        }
        self.progressTracker = progressPack
        self.progressDirection = progressPack?.direction
        self.thumbnailViewModel = ThumbnailImageViewModel(node: node, loader: thumbnailLoader)
        self.progressCancellable = progressPack?.progressPublisher()?
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
        file?.activeRevision?.thumbnail
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
        ((self.state == .uploading || self.file?.uploadID != nil) && self.progress == nil && self.progressesAvailable)
    }
    
    var uploadWaiting: Bool {
        self.state == .cloudImpediment
    }
    
    var uploadPaused: Bool {
        [Node.State.paused, .interrupted].contains(state)
    }
    
    private var percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.multiplier = 100
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var secondLineSubtitle: String {
        switch self.progress {
        case _ where uploadPaused:
            return "Paused"
            
        case _ where self.state == .cloudImpediment:
            return "Waiting..."
            
        case .none where self.uploadFailed:
            return "Upload failed"

        case .some where self.progressCompleted != 0 && self.isInProgress:
            return percentageDownloaded + (self.progressDirection == .upstream ? " uploaded..." : " downloaded")
            
        case .some where self.isInProgress:
            return self.progressDirection == .upstream ? "Uploading..." : "Downloading..."
            
        case .some, .none:
            return self.isFolderDownloading ? "Downloading..." : self.defaultSecondLineSubtitle
        }
    }

    var isFolderDownloading: Bool {
        (nodeType == .folder) && isSavedForOffline && !isDownloaded
    }

    var percentageDownloaded: String {
        percentFormatter.string(from: self.progressCompleted as NSNumber) ?? ""
    }
    
    var nodeType: NodeType {
        if node is Folder {
            return .folder
        } else {
            return .file
        }
    }
}
