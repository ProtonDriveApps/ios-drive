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
import UIKit

final class NotificationsPermissionsCoordinator {
    private let windowScene: UIWindowScene
    private let controller: NotificationsPermissionsFlowController
    private let viewControllerFactory: (() -> UIViewController)
    private let transparentViewControllerFactory: (() -> UIViewController)
    private var cancellable: AnyCancellable?
    private weak var viewController: UIViewController?
    private weak var previousWindow: UIWindow?
    private var window: UIWindow?
    
    init(windowScene: UIWindowScene, controller: NotificationsPermissionsFlowController, viewControllerFactory: @escaping (() -> UIViewController), transparentViewControllerFactory: @escaping (() -> UIViewController)) {
        self.windowScene = windowScene
        self.controller = controller
        self.viewControllerFactory = viewControllerFactory
        self.transparentViewControllerFactory = transparentViewControllerFactory
        setupObserving()
    }
    
    deinit {
        closeWindow()
    }
    
    private func setupObserving() {
        cancellable = controller.event
            .removeDuplicates()
            .sink { [weak self] event in
                self?.handle(event)
            }
    }
    
    private func handle(_ event: NotificationsPermissionsEvent) {
        switch event {
        case .open:
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                self?.open()
            }
        case .close:
            close()
        }
    }
    
    private func open() {
        // Needs to be in a separate window because other modals can be triggered at the same time.
        previousWindow = windowScene.keyWindow
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = transparentViewControllerFactory()
        window.makeKeyAndVisible()
        let viewController = viewControllerFactory()
        self.viewController = viewController
        window.rootViewController?.present(viewController, animated: true)
        self.window = window
    }
    
    private func close() {
        if let viewController = viewController {
            viewController.dismiss(animated: true) { [weak self] in
                self?.closeWindow()
            }
        } else {
            closeWindow()
        }
    }
    
    private func closeWindow() {
        previousWindow?.makeKeyAndVisible()
        window = nil
    }
}
