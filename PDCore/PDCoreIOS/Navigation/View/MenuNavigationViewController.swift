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

public final class MenuNavigationViewController: UINavigationController {
    override public init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        let menuButton = makeMenuButton()
        menuButton.accessibilityIdentifier = "Button.BurgerMenu"
        rootViewController.navigationItem.leftBarButtonItem = menuButton
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeMenuButton() -> UIBarButtonItem {
        let button = UIButton(frame: .zero)
        button.setSizeContraint(height: 24, width: 24)
        button.tintColor = ColorProvider.IconNorm
        button.setBackgroundImage(IconProvider.hamburger, for: .normal)
        button.addTarget(self, action: #selector(tapMenuButton), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            container.widthAnchor.constraint(equalToConstant: 40),
            container.heightAnchor.constraint(equalToConstant: 40)
        ])

        return UIBarButtonItem(customView: container)
    }

    @objc
    private func tapMenuButton() {
        NotificationCenter.default.post(name: DriveNotification.toggleSideMenu.name)
    }
}
