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

import Foundation
import PDCore
import PDCoreIOS
import PDSDKCore
import struct PDUIComponents.ContextMenuItem
import struct PDUIComponents.ContextMenuItemGroup

@MainActor
protocol FFinderNodeActionMenuHandling: AnyObject {
    func configShareMember(node: NodeDTO)
    func copyBookmark(node: NodeDTO)
    func downloadToDevice(node: NodeDTO)
    func move(node: NodeDTO)
    func openIn(node: NodeDTO)
    func openInBrowser(node: NodeDTO)
    func pauseUpload(node: NodeDTO)
    func removeBookmark(node: NodeDTO)
    func removeMe(node: NodeDTO)
    func removeUpload(node: NodeDTO)
    func rename(node: NodeDTO)
    func restartUpload(node: NodeDTO)
    func showDetails(node: NodeDTO)
    func toggleAvailableOffline(node: NodeDTO)
    func trash(node: NodeDTO)
}

/// View model for the `...` button menu in each cell
/// including the available menu items and their corresponding actions
@MainActor
final class FFinderNodeActionMenuViewModel {
    typealias EditSectionItem = EditSectionViewModel.EditSectionItem
    typealias MoreSectionItem = MoreSectionViewModel.MoreSectionItem
    private weak var actionHandler: FFinderNodeActionMenuHandling?
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let isSharedWithMeRoot: Bool
    private let node: NodeDTO

    init(
        actionHandler: FFinderNodeActionMenuHandling,
        featureFlagsController: FeatureFlagsControllerProtocol,
        isSharedWithMeRoot: Bool,
        node: NodeDTO
    ) {
        self.actionHandler = actionHandler
        self.featureFlagsController = featureFlagsController
        self.isSharedWithMeRoot = isSharedWithMeRoot
        self.node = node
    }

    func editActionGroups() -> [ContextMenuItemGroup] {
        let groups = [
            shareSectionItems,
            secondSectionItems,
            thirdSectionItems
        ].filter { !$0.isEmpty }
        return groups.map { group in
            return ContextMenuItemGroup(id: "editSection\(group[0].id)", items: group)
        }
    }
    
    func moreActionGroup() -> ContextMenuItemGroup? {
        guard node.canExport else { return nil }
        return ContextMenuItemGroup(id: "moreSection", items: [openIn, downloadToDevice])
    }

    func uploadActionGroups() -> ContextMenuItemGroup {
        return ContextMenuItemGroup(id: "uploadManagementSection", items: [pauseUpload, removeUpload])
    }

    func restartUpload(node: NodeDTO) {
        actionHandler?.restartUpload(node: node)
    }

    func removeUpload(node: NodeDTO) {
        actionHandler?.removeUpload(node: node)
    }
}

// MARK: - Edit Sections
extension FFinderNodeActionMenuViewModel {
    private var shareSectionItems: [ContextMenuItem] {
        if node.isBookmark { return [copyBookmark] }
        
        if featureFlagsController.hasSharing {
            let sharingPolicy = NodeSharingPolicy(
                role: node.role,
                permissions: node.permissions,
                featureFlagsController: featureFlagsController,
                shareAllowsEditorManagement: node.local.editorsCanShare
            )
            if sharingPolicy.canManageSharing() {
                return[configShareMember]
            }
        }

        return []
    }
    
    private var secondSectionItems: [ContextMenuItem] {
        if node.isBookmark { return [] }

        if isSharedWithMeRoot {
            return [download].compactMap { $0 }
        } else {
            let role = node.role
            switch role {
            case .viewer:
                return [download].compactMap { $0 }
            case .editor, .admin, .owner:
                return [download, rename, move].compactMap { $0 }
            }
        }
    }
    
    private var thirdSectionItems: [ContextMenuItem] {
        if node.isBookmark { return [removeBookmark] }

        if isSharedWithMeRoot {
            return [showDetails, removeMe].compactMap { $0 }
        } else {
            switch node.permissions {
            case .view:
                return [showDetails].compactMap { $0 }
            case .edit:
                return [openInBrowser, showDetails, trash].compactMap { $0 }
            case .administrate:
                return [openInBrowser, showDetails, trash].compactMap { $0 }
            }
        }
    }
    
    private var copyBookmark: ContextMenuItem {
        ContextMenuItem(
            sectionItem: EditSectionItem.copyBookmark,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.copyBookmark(node: self.node)
            }
        )
    }
    
    private var removeBookmark: ContextMenuItem {
        ContextMenuItem(
            sectionItem: EditSectionItem.removeBookmark,
            role: .destructive,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.removeBookmark(node: self.node)
            }
        )
    }
    
    private var configShareMember: ContextMenuItem {
        ContextMenuItem(
            sectionItem: EditSectionItem.configShareMember,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.configShareMember(node: self.node)
            }
        )
    }
    
    private var download: ContextMenuItem? {
        guard node.isDownloadable else { return nil }
        return ContextMenuItem(
            sectionItem: EditSectionItem.download(isMarked: node.isEligibleForAvailableOffline),
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.toggleAvailableOffline(node: self.node)
            }
        )
    }

    private var rename: ContextMenuItem? {
        if node.isPhoto { return nil }
        return ContextMenuItem(
            sectionItem: EditSectionItem.rename,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.rename(node: self.node)
            }
        )
    }

    private var move: ContextMenuItem? {
        if node.isPhoto { return nil }
        return ContextMenuItem(
            sectionItem: EditSectionItem.move,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.move(node: self.node)
            }
        )
    }

    private var openInBrowser: ContextMenuItem? {
        guard node.isProtonFile else { return nil }
        return ContextMenuItem(
            sectionItem: EditSectionItem.openInBrowser,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.openInBrowser(node: self.node)
            }
        )
    }
    
    private var showDetails: ContextMenuItem {
        ContextMenuItem(
            sectionItem: EditSectionItem.details(isFile: node.isFile),
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.showDetails(node: self.node)
            }
        )
    }
    
    private var removeMe: ContextMenuItem {
        ContextMenuItem(
            sectionItem: EditSectionItem.removeMe,
            role: .destructive,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.removeMe(node: self.node)
            }
        )
    }
    
    private var trash: ContextMenuItem {
        ContextMenuItem(
            sectionItem: EditSectionItem.remove,
            role: .destructive,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.trash(node: self.node)
            }
        )
    }
}

// MARK: - More Sections
extension FFinderNodeActionMenuViewModel {
    private var openIn: ContextMenuItem {
        ContextMenuItem(
            sectionItem: MoreSectionItem.shareIn,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.openIn(node: self.node)
            }
        )
    }
    
    private var downloadToDevice: ContextMenuItem {
        ContextMenuItem(
            sectionItem: MoreSectionItem.download,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.downloadToDevice(node: self.node)
            }
        )
    }
}

// MARK: - Upload
extension FFinderNodeActionMenuViewModel {
    private var pauseUpload: ContextMenuItem {
        ContextMenuItem(
            sectionItem: UploadManagementMenuViewModel.UploadManagementItem.pause,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.pauseUpload(node: self.node)
            }
        )
    }

    private var removeUpload: ContextMenuItem {
        ContextMenuItem(
            sectionItem: UploadManagementMenuViewModel.UploadManagementItem.remove,
            handler: { [weak self] in
                guard let self else { return }
                self.actionHandler?.removeUpload(node: self.node)
            }
        )
    }
}
