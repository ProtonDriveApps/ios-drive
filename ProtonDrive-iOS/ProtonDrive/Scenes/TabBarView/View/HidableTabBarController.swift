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
import SwiftUI
import PDCoreIOS
import PDCore

final class HidableTabBarController: UITabBarController, UITabBarControllerDelegate {
    private var cancellable: Cancellable?
    private var viewModel: TabBarViewModelProtocol

    init(viewModel: TabBarViewModelProtocol, children: [UIViewController]) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        setViewControllers(children, animated: false)
        let homeTabTag = viewModel.defaultHomeTab
        let currentTab = TabBarItem(rawValue: homeTabTag)?.title ?? "unknown"
        Log.info("[TabBar] Initial tab at launch: \(currentTab), total tabs: \(children.count)", domain: .userAction)
        guard let selectedViewController = children.first(where: { $0.tabBarItem.tag == homeTabTag }) else { return }
        self.selectedViewController = selectedViewController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

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
        moveTabBarToBottom()
    }

    func updateTabBarVisibility(_ isHidden: Bool) {
        setTabBarHidden(isHidden)
    }

    func setTabBarHidden(_ hidden: Bool, duration: TimeInterval = 0.3) {
        guard tabBar.isHidden != hidden else {
            return
        }

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
            // To fix safe area insets
            let currentFrame = self.view.frame
            self.view.frame = currentFrame.insetBy(dx: 0, dy: 1)
            self.view.frame = currentFrame
        })
        Log.info("[TabBar] Tab bar hidden: \(hidden)", domain: .userAction)
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let currentVC = selectedViewController {
            let currentTab = TabBarItem(rawValue: currentVC.tabBarItem.tag)?.title ?? "unknown"
            let nextTab = TabBarItem(rawValue: viewController.tabBarItem.tag)?.title ?? "unknown"
            Log.info("[TabBar] Will change tab from \(currentTab) to \(nextTab)", domain: .userAction)
        }
        return true
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        viewModel.selectTab(tag: item.tag)
    }

    // after iOS 18, iPad moves tab bar to the top by default
    private func moveTabBarToBottom() {
        guard
          #available (iOS 18.0, *),
          UIDevice.current.userInterfaceIdiom == .pad
        else { return }
//        mode = .tabBar
        traitOverrides.horizontalSizeClass = .compact
        view.addSubview(tabBar)
        let tabContainerClassName = "_UITabContainerView"
        for subView in view.subviews where String(describing: type(of: subView)) == tabContainerClassName {
            subView.isHidden = true
        }
      }
}
