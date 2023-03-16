//
//  NotificationsPermissionsCoordinator.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 02.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Combine
import UIKit

final class NotificationsPermissionsCoordinator {
    private let controller: NotificationsPermissionsFlowController
    private let viewControllerFactory: (() -> UIViewController)
    private var cancellable: AnyCancellable?
    private weak var viewController: UIViewController?
    
    init(controller: NotificationsPermissionsFlowController, viewControllerFactory: @escaping (() -> UIViewController)) {
        self.controller = controller
        self.viewControllerFactory = viewControllerFactory
        cancellable = controller.event
            .sink { [weak self] event in
                self?.handle(event)
            }
    }
    
    private func handle(_ event: NotificationsPermissionsEvent) {
        switch event {
        case .open:
            let viewController = viewControllerFactory()
            getTopViewController()?.present(viewController, animated: true)
            self.viewController = viewController
        case .close:
            viewController?.dismiss(animated: true)
        }
    }

    private func getTopViewController() -> UIViewController? {
        var rootViewController = UIApplication.shared.topViewController()
        if rootViewController?.isBeingDismissed ?? false {
            rootViewController = rootViewController?.presentingViewController
        }
        return rootViewController
    }
}
