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

extension UIApplication {
    
    func rootViewController() -> UIViewController? {
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows where window.isKeyWindow {
                    return window.rootViewController
                }
            }
        }
        
        return nil
    }
    
    func topViewController() -> UIViewController? {
        var topViewController = rootViewController()
        while true {
            if let presented = topViewController?.presentedViewController {
                topViewController = presented
            } else if let navController = topViewController as? UINavigationController {
                topViewController = navController.topViewController
            } else if let tabBarController = topViewController as? UITabBarController {
                topViewController = tabBarController.selectedViewController
            } else {
                // Handle any other third party container in `else if` if required
                break
            }
        }
        return topViewController
    }

    func topMostViewControllerFromAppWindow() -> UIViewController? {
        guard let windowScene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first?.rootViewController else {
            return nil
        }

        return topViewController(from: root)
    }

    private func topViewController(from root: UIViewController) -> UIViewController {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController ?? nav)
        } else if let tab = root as? UITabBarController,
                  let selected = tab.selectedViewController {
            return topViewController(from: selected)
        } else if let presented = root.presentedViewController {
            return topViewController(from: presented)
        } else {
            return root
        }
    }
}
