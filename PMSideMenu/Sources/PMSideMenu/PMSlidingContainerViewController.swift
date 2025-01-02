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
import Combine
#if canImport(SideMenuSwift)
import SideMenuSwift
#endif
#if canImport(SideMenu)
import SideMenu
#endif

final class DriveSideMenuController: SideMenuController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            super.viewWillTransition(to: size, with: coordinator)
        }
    }
}

internal final class PMSlidingContainerViewController: UIViewController, PMSlidingContainer {
    internal var onMenuToggle: ((Bool) -> Void)? = nil
    
    private let config = Configuration()
    private var controller: SideMenuController!
    private var cancellables: Set<AnyCancellable> = []
    
    required internal convenience init(skeleton: UIViewController,
                                     menu: UIViewController,
                                     togglePublisher: NotificationCenter.Publisher? = nil)
    {
        self.init()
        
        self.setupAppearance()
        self.controller = DriveSideMenuController(contentViewController: skeleton, menuViewController: menu)
        self.controller.delegate = self

        togglePublisher?
            .sink(receiveValue: { [weak self] _ in self?.revealMenu() })
            .store(in: &cancellables)
    }
    
    internal func setContent(to destination: UIViewController) {
        controller.setContentViewController(to: destination)
        controller.hideMenu(animated: true, completion: nil)
    }
    
    internal func revealMenu() {
        controller.revealMenu(animated: true, completion: nil)
    }
    
}

extension PMSlidingContainerViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            super.traitCollectionDidChange(previousTraitCollection)
            controller.hideMenu(animated: false, completion: nil)
        }
    }

}

extension PMSlidingContainerViewController: SideMenuControllerDelegate {
    
    private func setupAppearance() {
        SideMenuController.preferences.basic.menuWidth = config.menuPreferredWidth
        SideMenuController.preferences.basic.position = .sideBySide
        SideMenuController.preferences.basic.enablePanGesture = true
        SideMenuController.preferences.basic.enableRubberEffectWhenPanning = false
        SideMenuController.preferences.basic.shouldRespectLanguageDirection = false
        
        SideMenuController.preferences.animation.shadowColor = config.shadowColor
        SideMenuController.preferences.animation.shadowAlpha = config.shadowAlpha
        SideMenuController.preferences.animation.revealDuration = config.revealDuration
        SideMenuController.preferences.animation.hideDuration = config.hideDuration
        SideMenuController.preferences.animation.shouldAddShadowWhenRevealing = true
    }
    
    private func recalculateMenuWidth() -> CGFloat {
        guard let windowWidth = view.window?.bounds.width else {
            return config.menuPreferredWidth
        }
        
        return min(config.menuPreferredWidth, windowWidth - config.maximumMenuGap)
    }
    
    func sideMenuControllerWillRevealMenu(_ sideMenuController: SideMenuController) {
        let recalculatedMenuWidth = recalculateMenuWidth()
        
        SideMenuController.preferences.basic.menuWidth = recalculatedMenuWidth
        sideMenuController.menuViewController.additionalSafeAreaInsets.left = sideMenuController.view.bounds.width - recalculatedMenuWidth
        sideMenuController.menuViewController.viewSafeAreaInsetsDidChange()
        
        sideMenuController.menuViewController.view.accessibilityElementsHidden = false
        sideMenuController.contentViewController.view.accessibilityElementsHidden = true
        sideMenuController.contentViewController.view.isUserInteractionEnabled = false
        
        onMenuToggle?(true)
    }

    func sideMenuControllerWillHideMenu(_ sideMenuController: SideMenuController) {
        onMenuToggle?(false)
        
        SideMenuController.preferences.basic.menuWidth = recalculateMenuWidth()
        sideMenuController.menuViewController.additionalSafeAreaInsets = .zero
        sideMenuController.menuViewController.viewSafeAreaInsetsDidChange()
        
        sideMenuController.menuViewController.view.accessibilityElementsHidden = true
        sideMenuController.contentViewController.view.accessibilityElementsHidden = false
        sideMenuController.contentViewController.view.isUserInteractionEnabled = true
    }
}
