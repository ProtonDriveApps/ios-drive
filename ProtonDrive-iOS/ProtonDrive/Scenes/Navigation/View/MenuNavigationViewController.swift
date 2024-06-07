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

import ProtonCoreUIFoundations
import PDUIComponents
import UIKit

final class MenuNavigationViewController: UINavigationController {

    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        rootViewController.navigationItem.leftBarButtonItem = makeMenuButton()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeMenuButton() -> UIBarButtonItem {
        let menuAction = UIAction(
            title: "",
            image: IconProvider.hamburger,
            attributes: .disabled,
            state: .off,
            handler: { _ in NotificationCenter.default.post(.toggleSideMenu) }
        )
        let menuBarButtonItem = UIBarButtonItem(primaryAction: menuAction)
        menuBarButtonItem.tintColor = ColorProvider.IconNorm
        return menuBarButtonItem
    }
}
