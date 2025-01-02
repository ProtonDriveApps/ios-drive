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

import Combine
import PDLocalization
import PDCore
import PDUIComponents
import SwiftUI
import ProtonCoreUIFoundations

final class EditSectionViewModel: ObservableObject {
    @Published var node: Node
    let nodeEditionViewModel: NodeEditionViewModel
    let featureFlagsController: FeatureFlagsControllerProtocol
    private var isSharedWithMeRoot: Bool

    private var cancellables = Set<AnyCancellable>()

    init(node: Node, model: NodeEditionViewModel, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.node = node
        self.nodeEditionViewModel = model
        self.featureFlagsController = featureFlagsController
        self.isSharedWithMeRoot = model.isSharedWithMeRoot
        self.node.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var groups: [[EditSectionItem]] {
        return [
            shareSectionItems,
            secondSectionItems,
            thirdSectionItems
        ].filter { !$0.isEmpty }
    }

    var shareSectionItems: [EditSectionItem] {
        var shareSection: [EditSectionItem] = []

        if featureFlagsController.hasSharing && node.getNodeRole() == .admin {
            shareSection.append(configShareMember)
        }

        return shareSection
    }

    var secondSectionItems: [EditSectionItem] {
        if isSharedWithMeRoot {
            return [download].compactMap { $0 }
        } else {
            switch node.getNodeRole() {
            case .viewer:
                return [download].compactMap { $0 }
            case .editor:
                return [download, rename, move].compactMap { $0 }
            case .admin:
                if featureFlagsController.hasSharing {
                    return [download, rename, move].compactMap { $0 }
                } else {
                    return [download, shareLink, rename, move].compactMap { $0 }
                }
            }
        }
    }

    var thirdSectionItems: [EditSectionItem] {
        if isSharedWithMeRoot {
            return [.details(isFile: isFile), .removeMe].compactMap { $0 }
        } else {
            switch node.getNodeRole() {
            case .viewer:
                return [.details(isFile: isFile)].compactMap { $0 }
            case .editor:
                return [openInBrowser, .details(isFile: isFile), .remove].compactMap { $0 }
            case .admin:
                return [openInBrowser, .details(isFile: isFile), .remove].compactMap { $0 }
            }
        }
    }

    var isFile: Bool {
        node is File
    }

    var parentsChain: [Folder] {
        node.parentsChain()
    }

    func starNode() {
        nodeEditionViewModel.setFavorite(!node.isFavorite, nodes: [node])
    }
    
    func markOfflineAvailable() {
        nodeEditionViewModel.markOfflineAvailable(!node.isMarkedOfflineAvailable, nodes: [node])
    }
    
    private var configShareMember: EditSectionItem {
        return .configShareMember
    }
    
    private var download: EditSectionItem? {
        guard node.isDownloadable else { return nil }
        return .download(isMarked: node.isMarkedOfflineAvailable)
    }

    private var shareLink: EditSectionItem? {
        .shareLink(exists: self.node.isShared)
    }

    private var rename: EditSectionItem? {
        if node is Photo {
            return nil
        } else {
            return .rename
        }
    }

    private var move: EditSectionItem? {
        if node is Photo {
            return nil
        } else {
            return .move
        }
    }

    private var openInBrowser: EditSectionItem? {
        if (node as? File)?.isProtonDocument ?? false {
            return .openInBrowser
        } else {
            return nil
        }
    }
}

extension EditSectionViewModel {
    enum EditSectionItem: SectionItemDisplayable, Equatable {
        case share
        case configShareMember
        case download(isMarked: Bool)
        case shareLink(exists: Bool)
        case rename
        case move
        case details(isFile: Bool)
        case remove
        case openInBrowser
        case removeMe

        var text: String {
            switch self {
            case .share:
                return Localization.general_share
            case .configShareMember:
                return Localization.general_share
            case .download(let isMarked):
                return isMarked ? Localization.edit_section_remove_from_available_offline : Localization.edit_section_make_available_offline
            case .shareLink(exists: let exists):
                return exists ? Localization.edit_section_sharing_options : Localization.edit_section_share_via_link
            case .rename:
                return Localization.general_rename
            case .move:
                return Localization.edit_section_move_to
            case .details(let isFile):
                return isFile ? Localization.edit_section_show_file_details : Localization.edit_section_show_folder_details
            case .remove:
                return Localization.edit_section_remove
            case .openInBrowser:
                return Localization.edit_section_open_in_browser
            case .removeMe:
                return Localization.edit_section_remove_me
            }
        }

        var icon: Image {
            switch self {
            case .share: return IconProvider.arrowUpFromSquare
            case .configShareMember: return IconProvider.userPlus
            case .download: return IconProvider.arrowDownCircle
            case .shareLink: return IconProvider.link
            case .rename: return IconProvider.penSquare
            case .move: return IconProvider.folderArrowIn
            case .details: return IconProvider.infoCircle
            case .remove: return IconProvider.trash
            case .openInBrowser: return IconProvider.arrowOutSquare
            case .removeMe: return .init("ic_user_cross")
            }
        }

        var identifier: String {
            let name: String
            switch self {
            case .share: name = "share"
            case .configShareMember: name = "shareConfiguration"
            case .download(let isMarked): name = isMarked ? "removeFromOffline" : "makeAvailableOffline"
            case .shareLink(exists: let exists): name = exists ? "shareOptions" : "shareLink"
            case .rename: name = "rename"
            case .move: return "move"
            case .details: return "details"
            case .remove: return "remove"
            case .openInBrowser: name = "openInBrowser"
            case .removeMe: return "removeMe"
            }
            return "EditSectionItem.\(name)"
        }
    }

    struct EditSectionRow: Identifiable {
        let id = UUID()
        let type: EditSectionItem

        init?(type: EditSectionItem?) {
            guard let type = type else { return nil }
            self.type = type
        }
    }
}

extension EditSectionViewModel.EditSectionItem: Identifiable, MirrorableEnum {
    var id: String { self.mirror.label }
}
