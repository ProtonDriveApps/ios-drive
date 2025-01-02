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

import ProtonCoreUIFoundations
import UIKit

final class ProtonDocumentActionsMenu: UIMenu {
    convenience init(viewModel: ProtonDocumentActionsViewModelProtocol) {
        let sections = viewModel.sections.map { section in
            let actions = section.map { action in
                let actionButton = UIAction(title: action.title, image: action.image) { _ in
                    viewModel.invoke(action: action.type)
                }
                actionButton.accessibilityLabel = action.accessibilityLabel
                return actionButton
            }
            return UIMenu(title: "", options: .displayInline, children: actions)
        }
        self.init(children: sections)
    }
}

private extension ProtonDocumentAction {
    var image: UIImage? {
        switch self.type {
        case .openInBrowser:
            return IconProvider.arrowOutSquare
        case .rename:
            return IconProvider.penSquare
        }
    }
}
