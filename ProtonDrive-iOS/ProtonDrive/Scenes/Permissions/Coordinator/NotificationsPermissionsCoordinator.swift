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
    private var cancellable: AnyCancellable?
    private weak var viewController: UIViewController?
    
    var viewControllerFactory: (() -> UIViewController)?
    
    init(controller: NotificationsPermissionsFlowController) {
        self.controller = controller
        cancellable = controller.event
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .sink { [weak self] event in
                self?.handle(event)
            }
    }
    
    private func handle(_ event: NotificationsPermissionsEvent) {
        switch event {
        case .open:
            guard let viewController = viewControllerFactory?() else { return }
            let rootViewController = UIApplication.shared.topViewController()
            rootViewController?.present(viewController, animated: true)
            self.viewController = viewController
        case .close:
            viewController?.dismiss(animated: true)
        }
    }
}
