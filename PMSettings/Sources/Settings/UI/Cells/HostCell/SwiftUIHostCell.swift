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

import SwiftUI
import ProtonCoreUIFoundations

final class SwiftUIHostCell<Content: View>: PMSettingsBaseCell {
    private var hostingController: UIHostingController<Content>?

    func configure(with content: Content, parent: UIViewController) {
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        hostingController = UIHostingController(rootView: content)
        if let hostingController = hostingController {
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.backgroundColor = ColorProvider.BackgroundNorm
            contentView.addSubview(hostingController.view)
            parent.addChild(hostingController)

            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 44) // Minimum height
            ])

            hostingController.didMove(toParent: parent)
        }
    }
}
