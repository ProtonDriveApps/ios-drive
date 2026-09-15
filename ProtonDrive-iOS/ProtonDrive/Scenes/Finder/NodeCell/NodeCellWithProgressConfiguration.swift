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
import PDCoreIOS
import PDUIComponents
import SwiftUI
import PDLocalization

class NodeCellWithProgressConfiguration: ObservableObject, NodeCellConfiguration {
    @Published var node: Node
    @Published var progressCompleted: Double = 0
    @Published var availableOfflineFlags: NodeCellAvailableOfflineFlags = .notAvailable

    let thumbnailViewModel: ThumbnailImageViewModel
    var nodeRowActionMenuViewModel: NodeRowActionMenuViewModel?
    var uploadManagementMenuViewModel: UploadManagementMenuViewModel?
    private let nodeStatePolicy: NodeStatePolicy

    private var cancellables = Set<AnyCancellable>()
    private var progressCancellable: AnyCancellable?
    @Published private var progressTracker: ProgressTracker?
    private var progressesAvailable: Bool
    private var progress: Progress? {
        self.progressTracker?.progress
    }

    let iconName: FileAssetName
    var name: String
    var isFavorite: Bool { node.isFavorite }
    var isShared: Bool { node.isShared }
    var hasSharing: Bool { featureFlagsController.hasSharing }
    var hasDirectShare: Bool { node.hasDirectShare }
    var lastModified: Date { node.modifiedDate }
    var size: Int {
        if let file = node as? CoreDataFile {
            return file.activeRevision?.size ?? file.size
        } else {
            return node.size
        }
    }

    @Published var progressDirection: ProgressTracker.Direction?
    let isDisabled = false
    let selectionModel: CellSelectionModel?
    lazy var id: NodeIdentifier = {
        node.identifier // Using `node.identifierWithinManagedObjectContext` causes crashes for unknown reasons
    }()
    var featureFlagsController: FeatureFlagsControllerProtocol

    var actionButtonAction: () -> Void = { }
    var retryUploadAction: () -> Void = { }
    var cancelUploadAction: () -> Void = { }

    var isSharedWithMeRoot: Bool
    let progressTrackersController: ProgressTrackersControllerProtocol
    let nodeDownloadedResource: NodeDownloadedResource

    init(from node: Node,
         fileTypeAsset: FileTypeAsset = .shared,
         selectionModel: CellSelectionModel? = nil,
         progressesAvailable: Bool = false,
         thumbnailLoader: SDKThumbnailsDownloaderProtocol?,
         nodeStatePolicy: NodeStatePolicy,
         featureFlagsController: FeatureFlagsControllerProtocol,
         isSharedWithMeRoot: Bool,
         progressTrackersController: ProgressTrackersControllerProtocol,
         nodeDownloadedResource: NodeDownloadedResource
    ) {
        self.isSharedWithMeRoot = isSharedWithMeRoot
        self.progressesAvailable = progressesAvailable
        self.node = node
        self.selectionModel = selectionModel
        self.name = node.decryptedName
        self.nodeStatePolicy = nodeStatePolicy

        self.iconName = fileTypeAsset.getAsset(node.mimeType)

        self.thumbnailViewModel = ThumbnailImageViewModel(node: node, loader: thumbnailLoader)
        self.featureFlagsController = featureFlagsController
        self.progressTrackersController = progressTrackersController
        self.nodeDownloadedResource = nodeDownloadedResource

        subscribeToProgresses()
        fetchAvailableOfflineIfNecessary()
    }

    // MARK: - Subscriptions to progress

    private func subscribeToProgresses() {
        if let file {
            // `id` in case of download, `uploadID` in case of upload
            let ids = [id.id, file.uploadID?.uuidString].compactMap({ $0 })
            progressTrackersController.getPublisher(for: ids)
                .sink { [weak self] progressTracker in
                    self?.handleProgressTrackerUpdate(progressTracker)
                }
                .store(in: &cancellables)
        } else {
            // In case of folders, we need to refresh when children finish (and we don't necessarily have all their ids handy)
            progressCancellable = progressTrackersController.getDownloadsPublisher()
                .receive(on: DispatchQueue.main)
                .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] in
                    self?.handleDownloadsUpdate()
                }
        }
    }

    private func handleProgressTrackerUpdate(_ progressTracker: ProgressTracker?) {
        if self.progressTracker != nil && progressTracker == nil {
            // Progress probably completed, since it was nilled. Need to refresh node info.
            fetchAvailableOfflineIfNecessary()
            progressCompleted = 0
        } else if let progressTracker {
            // New progress notified, transfer happening
            subscribeToProgressCompleted(progressTracker)
        }
        self.progressTracker = progressTracker
        progressDirection = progressTracker?.direction
    }

    private func subscribeToProgressCompleted(_ progressTracker: ProgressTracker) {
        progressCancellable = progressTracker.progressPublisher()?
            .receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.progressCompleted = $0
            }
    }

    private func handleDownloadsUpdate() {
        guard availableOfflineFlags.isFolderDownloading else {
            // Only relevant in scope of folder
            return
        }

        // Refresh offline available flags
        fetchAvailableOfflineIfNecessary()
    }

    // MARK: Available offline flags

    private func fetchAvailableOfflineIfNecessary() {
        guard node.isEligibleForAvailableOffline && (progress == nil || !isInProgress) else {
            // If it's in progress, then we can avoid heavy operation below (the badge wouldn't be displayed anyway)
            availableOfflineFlags = .notAvailable
            return
        }

        nodeDownloadedResource.startLoading(for: id.any())
            .sink { [weak self] value in
                self?.handleIsAvailableOffline(value)
            }
            .store(in: &cancellables)
    }

    private func handleIsAvailableOffline(_ value: Bool) {
        availableOfflineFlags = NodeCellAvailableOfflineFlags(
            isAvailableOffline: value,
            isFolderDownloading: node is Folder && !value,
            isMarkedAsAvailableOffline: true
        )
    }

    // MARK: Computed properties

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
        self.progress?.isFinished == false && self.progress?.isCancelled == false && isNotPaused()
    }

    private func isNotPaused() -> Bool {
        ![Node.State.cloudImpediment, .interrupted, .paused].contains(node.state)
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

    var isBookmark: Bool {
        self.node is CoreDataBookmark
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
            return self.availableOfflineFlags.isFolderDownloading ? Localization.progress_status_downloading : self.defaultSecondLineSubtitle
        }
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
            if node is CoreDataBookmark {
                let createdDate = DateStamper.stamp(for: node.createdDate)
                let infoString = Localization.shared_with_me_bookmarks_second_line(date: createdDate)
                return infoString
            } else {
                return "\(inviter)•\(sharingDate)"
            }
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
        return DateFormatter.displayMediumDate.string(from: membership.modifyTime)
    }
}
