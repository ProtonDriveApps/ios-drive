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
import ProtonCoreUIFoundations

final class HidableTabBarController: UITabBarController {
    private var cancellable: Cancellable?
    private var viewModel: TabBarViewModelProtocol

    init(viewModel: TabBarViewModelProtocol, children: [UIViewController]) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        setViewControllers(children, animated: false)
        let homeTabTag = viewModel.defaultHomeTab
        guard let selectedViewController = children.first(where: { $0.tabBarItem.tag == homeTabTag }) else { return }
        self.selectedViewController = selectedViewController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let tabBarAppearance: UITabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = ColorProvider.BackgroundNorm

        UITabBar.appearance().tintColor = ColorProvider.BrandNorm
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        cancellable = viewModel.isTabBarHidden
            .sink { [weak self] isHidden in
                self?.updateTabBarVisibility(isHidden)
            }
    }

    func updateTabBarVisibility(_ isHidden: Bool) {
        setTabBarHidden(isHidden)
    }

    func setTabBarHidden(_ hidden: Bool, animated: Bool = true, duration: TimeInterval = 0.3) {
        if tabBar.isHidden != hidden {
            if animated {
                if tabBar.isHidden {
                    tabBar.isHidden = hidden
                }
                let frame = tabBar.frame
                let factor: CGFloat = hidden ? 1 : -1
                let y = frame.origin.y + (frame.size.height * factor)
                UIView.animate(withDuration: duration, animations: {
                    self.tabBarController?.tabBar.frame = CGRect(x: frame.origin.x, y: y, width: frame.width, height: frame.height)
                }, completion: { _ in
                    if !self.tabBar.isHidden {
                        self.tabBar.isHidden = hidden
                    }
                })
            }
        }
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        viewModel.selectTab(tag: item.tag)
    }
}
