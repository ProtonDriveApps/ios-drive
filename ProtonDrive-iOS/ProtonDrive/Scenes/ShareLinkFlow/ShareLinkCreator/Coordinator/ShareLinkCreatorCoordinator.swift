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

import UIKit
import SwiftUI
import PDCore

final class ShareLinkCreatorCoordinator {
    private var view: ShareLinkCreatorViewController!
    private var sharedViewControllerFactory: (ShareURL) -> UIViewController

    init(
        view: ShareLinkCreatorViewController,
        sharedViewControllerFactory: @escaping (ShareURL) -> UIViewController
    ) {
        self.view = view
        self.sharedViewControllerFactory = sharedViewControllerFactory
    }

    func goSharedLink(_ shareURL: ShareURL) {
        let vc = sharedViewControllerFactory(shareURL)
        view.navigationController?.setViewControllers([vc], animated: false)
    }
}
