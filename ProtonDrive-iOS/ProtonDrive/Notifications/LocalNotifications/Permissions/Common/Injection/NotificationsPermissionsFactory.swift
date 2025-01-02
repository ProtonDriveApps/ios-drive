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
import PDCore

struct NotificationsPermissionsFactory {
    func makeFlowController() -> NotificationsPermissionsFlowController {
        NotificationsPermissionsFlowControllerImpl(signOutPublisher: NotificationCenter.default.mappedPublisher(for: DriveNotification.signOut.name))
    }

    func makePermissionsCoordinator(controller: NotificationsPermissionsController, flowController: NotificationsPermissionsFlowController, windowScene: UIWindowScene, type: NotificationsPermissionsType) -> NotificationsPermissionsCoordinator {
        return NotificationsPermissionsCoordinator(windowScene: windowScene, controller: flowController, type: type, viewControllerFactory: {
            makePermissionsView(controller: controller, flowController: flowController, type: type)
        }, transparentViewControllerFactory: makeTransparentViewController)
    }

    private func makePermissionsView(controller: NotificationsPermissionsController, flowController: NotificationsPermissionsFlowController, type: NotificationsPermissionsType) -> UIViewController {
        let viewModel = NotificationsPermissionsViewModelImpl(type: type, controller: controller, flowController: flowController)
        let view = NotificationsPermissionsView(viewModel: viewModel)
        return NotificationsPermissionsHostingViewController(viewModel: viewModel, rootView: view)
    }

    private func makeTransparentViewController() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear
        return viewController
    }
}
