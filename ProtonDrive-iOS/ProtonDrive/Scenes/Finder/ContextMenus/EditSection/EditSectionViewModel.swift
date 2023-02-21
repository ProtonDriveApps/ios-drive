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
import PDCore
import PDUIComponents
import SwiftUI
import ProtonCore_UIFoundations

final class EditSectionViewModel: ObservableObject {
    @Published var node: Node
    let nodeEditionViewModel: NodeEditionViewModel

    private var cancellables = Set<AnyCancellable>()
    init(node: Node, model: NodeEditionViewModel) {
        self.node = node
        self.nodeEditionViewModel = model
        self.node.objectWillChange
        .sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }

    var items: [EditSectionItem] {
        [download, shareLink, .rename, .move, .details(isFile: isFile), .remove].compactMap { $0 }
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
    
    private var download: EditSectionItem {
        return .download(isMarked: node.isMarkedOfflineAvailable)
    }

    private var shareLink: EditSectionItem? {
        .shareLink(exists: self.node.isShared)
    }
}

extension EditSectionViewModel {
    enum EditSectionItem: SectionItemDisplayable {
        case share
        case download(isMarked: Bool)
        case shareLink(exists: Bool)
        case rename
        case move
        case details(isFile: Bool)
        case remove

        var text: String {
            let name: String
            switch self {
            case .share: name = "Share"
            case .download(let isMarked): name = isMarked ? "Remove from available offline" : "Make available offline"
            case .shareLink(exists: let exists): name = exists ? "Sharing options" : "Share via link"
            case .rename: name = "Rename"
            case .move: name = "Move to..."
            case .details(let isFile): name = isFile ? "Show file details" : "Show folder details"
            case .remove: name = "Move to trash"
            }
            return name
        }

        var icon: Image {
            let name: Image
            switch self {
            case .share: name = IconProvider.arrowUpFromSquare
            case .download: name = IconProvider.arrowDownCircle
            case .shareLink: name = IconProvider.link
            case .rename: name = IconProvider.penSquare
            case .move: name = IconProvider.folderArrowIn
            case .details: name = IconProvider.infoCircle
            case .remove: name = IconProvider.trash
            }
            return name
        }

        var identifier: String {
            let name: String
            switch self {
            case .share: name = "share"
            case .download(let isMarked): name = isMarked ? "removeFromOffline" : "makeAvailableOffline"
            case .shareLink(exists: let exists): name = exists ? "shareOptions" : "shareLink"
            case .rename: name = "rename"
            case .move: return "move"
            case .details: return "details"
            case .remove: return "remove"
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
