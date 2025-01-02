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

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
public struct NavigationControllerAccessor: UIViewControllerRepresentable {
    public typealias UIViewControllerType = UIViewController
    public typealias CallbackController = (UINavigationController) -> Void
        
    public let movedToParentCallback: CallbackController
    public let willAppearCallback: CallbackController
    public let didAppearCallback: CallbackController
    
    public init(movedToParentCallback: @escaping CallbackController = { _ in },
                willAppearCallback: @escaping CallbackController = { _ in },
                didAppearCallback: @escaping CallbackController = { _ in })
    {
        self.movedToParentCallback = movedToParentCallback
        self.willAppearCallback = willAppearCallback
        self.didAppearCallback = didAppearCallback
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<NavigationControllerAccessor>) -> UIViewController {
        let proxyController = ViewController()
        proxyController.movedToParentCallback = movedToParentCallback
        proxyController.willAppearCallback = willAppearCallback
        proxyController.didAppearCallback = didAppearCallback
        return proxyController
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<NavigationControllerAccessor>) {
        // nothing
    }

    private class ViewController: UIViewController {
        fileprivate var movedToParentCallback: CallbackController?
        fileprivate var willAppearCallback: CallbackController?
        fileprivate var didAppearCallback: CallbackController?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let navController = self.navigationController else {
                return
            }
            self.movedToParentCallback?(navController)
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let navController = self.navigationController else {
                return
            }
            self.willAppearCallback?(navController)
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navController = self.navigationController else {
                return
            }
            self.didAppearCallback?(navController)
        }
    }
}
#endif
