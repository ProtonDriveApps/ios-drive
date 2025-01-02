// Copyright (c) 2024 Proton AG
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
import PDLocalization
import PDCore

struct ProtonDocumentAction {
    enum ActionType {
        case rename
        case openInBrowser
    }

    let type: ActionType
    let title: String

    var accessibilityLabel: String {
        switch type {
        case .rename:
            return "ContextMenuItemActionView.EditSectionItem.rename"
        case .openInBrowser:
            return "ContextMenuItemActionView.EditSectionItem.openInBrowser"
        }
    }
}
typealias ProtonDocumentActionsSection = [ProtonDocumentAction]

protocol ProtonDocumentActionsViewModelProtocol {
    var sections: [ProtonDocumentActionsSection] { get }
    func invoke(action: ProtonDocumentAction.ActionType)
}

final class ProtonDocumentActionsViewModel: ProtonDocumentActionsViewModelProtocol {
    private let identifier: ProtonDocumentIdentifier
    private let coordinator: ProtonDocumentCoordinatorProtocol
    private let openingController: ProtonDocumentOpeningControllerProtocol

    var sections: [ProtonDocumentActionsSection] {
        // Using 2 dimensional array to add dividers in between. More actions to come in future
        return [
            [
                ProtonDocumentAction(type: .rename, title: Localization.general_rename)
            ],
            [
                ProtonDocumentAction(type: .openInBrowser, title: Localization.edit_section_open_in_browser)
            ]
        ]
    }

    init(identifier: ProtonDocumentIdentifier, coordinator: ProtonDocumentCoordinatorProtocol, openingController: ProtonDocumentOpeningControllerProtocol) {
        self.identifier = identifier
        self.coordinator = coordinator
        self.openingController = openingController
    }

    func invoke(action: ProtonDocumentAction.ActionType) {
        switch action {
        case .rename:
            coordinator.openRename(identifier: identifier)
        case .openInBrowser:
            let nodeIdentifier = NodeIdentifier(identifier.linkId, identifier.shareId, identifier.volumeId)
            openingController.openExternally(nodeIdentifier)
        }
    }
}
