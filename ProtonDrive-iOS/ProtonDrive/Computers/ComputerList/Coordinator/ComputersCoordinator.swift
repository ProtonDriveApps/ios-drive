// Copyright (c) 2025 Proton AG
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
import UIKit
import SwiftUI
import PDCoreIOS

protocol ComputersCoordinatorProtocol {
    typealias OriginalName = String

    func notifySideMenuToggle()
    func navigateNext(computer: ComputerIdentifier)
    func showDetails(for identifier: ComputerIdentifier)
    func rename(computer: ComputerIdentifier, originalName: OriginalName)
    func remove(computer: ComputerIdentifier, originalName: OriginalName)
    func goBack()
}

final class ComputersCoordinator: ComputersCoordinatorProtocol {
    weak var navigationController: UINavigationController?
    private let notificationCenter: NotificationCenter
    private let deviceRootViewControllerFactory: (ComputerIdentifier) -> UIViewController
    private let detailsScreenFactory: (ComputerIdentifier) -> UIViewController
    private let renameComputerFactory: (ComputerIdentifier, OriginalName) -> UIViewController
    private let deleteComputerFactory: (ComputerIdentifier, OriginalName) -> UIViewController

    init(
        deviceRootViewControllerFactory: @escaping (ComputerIdentifier) -> UIViewController,
        detailsScreenFactory: @escaping (ComputerIdentifier) -> UIViewController,
        renameComputerFactory: @escaping (ComputerIdentifier, OriginalName) -> UIViewController,
        deleteComputerFactory: @escaping (ComputerIdentifier, OriginalName) -> UIViewController,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.deviceRootViewControllerFactory = deviceRootViewControllerFactory
        self.detailsScreenFactory = detailsScreenFactory
        self.renameComputerFactory = renameComputerFactory
        self.deleteComputerFactory = deleteComputerFactory
        self.notificationCenter = notificationCenter
    }

    func goBack() {
        navigationController?.popViewController(animated: true)
    }

    func notifySideMenuToggle() {
        notificationCenter.post(.toggleSideMenu)
    }

    func navigateNext(computer: ComputerIdentifier) {
        let nextViewController = deviceRootViewControllerFactory(computer)
        navigationController?.pushViewController(nextViewController, animated: true)
    }

    func rename(computer: ComputerIdentifier, originalName: OriginalName) {
        let viewController = renameComputerFactory(computer, originalName)
        navigationController?.topViewController?.present(viewController, animated: true)
    }

    func showDetails(for identifier: ComputerIdentifier) {
        let viewController = detailsScreenFactory(identifier)
        viewController.modalPresentationStyle = .pageSheet
        navigationController?.topViewController?.present(viewController, animated: true)
    }

    func remove(computer: ComputerIdentifier, originalName: OriginalName) {
        let alertController = deleteComputerFactory(computer, originalName)

        guard let topViewController = navigationController?.topViewController else {
            return
        }

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = topViewController.view
            popoverController.sourceRect = topViewController.view.bounds
            popoverController.permittedArrowDirections = []
        }

        topViewController.present(alertController, animated: true)
    }
}
