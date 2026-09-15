// Copyright (c) 2026 Proton AG
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

import Combine
import Foundation
import PDCore
import PDCoreIOS
import PDSDKCore
import PDLocalization
import enum PDUIComponents.DateStamper
import struct PDUIComponents.ContextMenuItemGroup

@MainActor
final class FFinderCellViewModel: ObservableObject {
    @Published private var progressTracker: ProgressTracker?
    let dependencies: Dependencies
    let state: State
    
    private var cancellables = Set<AnyCancellable>()
    private var isFetchingThumbnail = false
    var isFolderDownloading: Bool {
        node.isFolder && node.isEligibleForAvailableOffline && !node.isDownloaded
    }
    var isInProgress: Bool {
        guard let progress = progressTracker?.progress else { return false }
        return progress.isFinished == false && progress.isCancelled == false && isNotPaused
    }
    var isNotPaused: Bool { dependencies.nodeStatePolicy.isNotPaused(for: node) }
    var isSelected: Bool { dependencies.multipleSelectionModel?.isSelected(node.id) ?? false }
    var isSelectionEnabled: Bool { dependencies.multipleSelectionModel?.isSelectionEnabled ?? false }
    var moreActionGroup: ContextMenuItemGroup? { dependencies.actionViewModel?.moreActionGroup() }
    var node: NodeDTO { state.node }
    var placeholderIconName: FileAssetName { dependencies.fileTypeAsset.getAsset(node.mimeType) }
    var progressCompleted: Double { progressTracker?.progress?.fractionCompleted ?? 0 }
    var progressDirection: ProgressTracker.Direction? { progressTracker?.direction }
    var progressPercentage: String { NumberFormatter.percent.string(from: progressCompleted as NSNumber) ?? "" }
    var separator: FinderListSeparator {
        isInProgress ? .progressing(progress: progressCompleted) : .divider
    }
    var uploadActionGroup: ContextMenuItemGroup? { dependencies.actionViewModel?.uploadActionGroups() }
    var uploadFailed: Bool {
        dependencies.nodeStatePolicy.isUploadFailed(
            for: node,
            progressTracker: progressTracker
        )
    }
    var uploadPaused: Bool { dependencies.nodeStatePolicy.isUploadPaused(for: node) }
    var uploadWaiting: Bool { dependencies.nodeStatePolicy.isUploadWaiting(for: node) }
    
    init(dependencies: Dependencies, state: State) {
        self.dependencies = dependencies
        self.state = state
        
        subscribeToUpdates()
    }
    
    private func subscribeToUpdates() {
        dependencies.multipleSelectionModel?.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        if !node.isFolder {
            let ids = [node.id.id, node.uploadID?.uuidString].compactMap { $0 }
            dependencies.progressTrackersController.getPublisher(for: ids)
                .sink { [weak self] progressTracker in
                    self?.progressTracker = progressTracker
                }
                .store(in: &cancellables)
        }
    }
    
    func thumbnail() -> Data? {
        let identifier = node.id.volumeBasedIdentifier
        let url = PDFileManager.getThumbnailURL(for: identifier, type: .default)
        if let url {
            // TODO: finder-refactor in-memory cache?
            return try? Data(contentsOf: url)
        } else if node.isFolder {
            return nil
        } else if !isFetchingThumbnail {
            isFetchingThumbnail = true
            downloadThumbnail()
        }
        return nil
    }

    private func downloadThumbnail() {
        guard node.activeRevision?.thumbnails.count ?? 0 > 0 else { return }
        Task {
            do {
                _ = try await dependencies.thumbnailLoader.downloadThumbnail(for: node.id, type: .default)
                await MainActor.run { self.objectWillChange.send() }
            } catch {
                Log.error("Download thumbnail failed", error: error, domain: .ui)
            }
            await MainActor.run { isFetchingThumbnail = false }
        }
    }

    var buttons: [NodeCellButton] {
        if dependencies.actionViewModel == nil {
            return []
        } else if uploadFailed || uploadWaiting || uploadPaused {
            return [
                .init(type: .cancel, action: { [weak self] in
                    guard let self else { return }
                    self.dependencies.actionViewModel?.removeUpload(node: self.state.node)
                }),
                .init(type: .retry, action: { [weak self] in
                    guard let self else { return }
                    self.dependencies.actionViewModel?.restartUpload(node: self.state.node)
                })
            ]
        } else {
            return [.init(type: .menu, action: {})]
        }
    }

    func editActionGroups() -> [ContextMenuItemGroup] {
        dependencies.actionViewModel?.editActionGroups() ?? []
    }
}

// MARK: - Second line
extension FFinderCellViewModel {
    var defaultSecondLineSubtitle: String {
        if state.isSharedWithMeRoot {
            if node.isBookmark {
                let createdDate = DateStamper.stamp(for: node.createdDate)
                let infoString = Localization.shared_with_me_bookmarks_second_line(date: createdDate)
                return infoString
            } else {
                let owner = node.ownedBy ?? node.keyAuthor?.emailAddress ?? ""
                var date: String = ""
                if let inviteTime = node.membership?.inviteTime {
                    date = DateFormatter.displayMediumDate.string(from: inviteTime)
                }
                return "\(owner)•\(date)"
            }
        } else {
            let suffix = "Modified \(DateStamper.stamp(for: node.modificationDate))"
            if node.isFolder == false, let size = node.activeRevision?.storageSize, size > 0 {
                let sizeString = ByteCountFormatter.storageSizeString(forByteCount: size)
                return "\(sizeString), \(suffix)"
            } else {
                return suffix
            }
        }
    }
    
    var secondLine: NodeListSecondLine {
        NodeListSecondLine(figure: figure, subtitle: subtitle, isFailedStyle: (uploadFailed && !uploadPaused))
    }
    
    private var figure: SecondLineFigure {
        if node.isBookmark {
            return .badges([.bookmark])
        }
        
        if isInProgress {
            return progressDirection == .downstream ? .spinner : .uploadSpinner
        } else if uploadPaused {
            return .paused
        } else if uploadFailed {
            return .warning
        } else if uploadWaiting {
            return .spinner
        } else {
            return .badges(badges)
        }
    }
    
    var badges: [Badge] {
        var badges: [Badge] = []
        
        if node.isFavorite {
            badges.append(.favorite)
        }
        
        if node.isAvailableOffline {
            badges.append(.offline)
        } else if node.isMarkedOfflineAvailable {
            badges.append(.markedAsOffline)
        }

        let hasSharing = dependencies.featureFlagsController.hasSharing
        if state.isSharedWithMeRoot && hasSharing {
            badges.append(.sharedCollaboratively)
        } else if node.isShared || (node.membership != nil && hasSharing) {
            badges.append(.shared)
        }

        return badges
    }
    
    private var subtitle: String {
        if isFolderDownloading {
            return Localization.progress_status_downloading
        } else if uploadPaused {
            return Localization.progress_status_paused
        } else if uploadWaiting {
            return Localization.progress_status_waiting
        } else if uploadFailed {
            return Localization.progress_status_upload_failed
        } else if isInProgress {
            guard let progressDirection else {
                return Localization.progress_status_upload_failed
            }
            if progressCompleted == 0 {
                return progressDirection == .upstream ? Localization.progress_status_uploading : Localization.progress_status_downloading
            }
            
            if progressDirection == .upstream {
                return Localization.progress_status_uploaded(percent: progressPercentage)
            } else {
                return Localization.progress_status_downloaded(percent: progressPercentage)
            }
        } else {
            return defaultSecondLineSubtitle
        }
    }
}

extension FFinderCellViewModel {
    struct Dependencies {
        let actionViewModel: FFinderNodeActionMenuViewModel?
        let featureFlagsController: FeatureFlagsControllerProtocol
        let fileTypeAsset: FileTypeAsset = FileTypeAsset.shared
        let multipleSelectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>?
        let nodeStatePolicy: NodeStatePolicy
        let progressTrackersController: ProgressTrackersControllerProtocol
        let thumbnailLoader: SDKThumbnailsDownloaderProtocol
        let transferManager: FinderTransferManaging
    }
    
    struct State {
        let isSharedWithMeRoot: Bool
        let node: NodeDTO
        let shouldDisable: Bool
    }
}
