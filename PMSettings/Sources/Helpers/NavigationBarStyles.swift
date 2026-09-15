// Copyright (c) 2022 Proton AG
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

import PDUIComponents
import UIKit
import ProtonCoreUIFoundations

public struct NavigationBarStyles {
    public static let `default` = Style<UINavigationBar> { _ in }

    public static let sheet = Style<UINavigationBar> { bar in
        let appearance = UINavigationBarAppearance.drive

        bar.standardAppearance = appearance
        bar.compactAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.isTranslucent = false
    }
}

extension UINavigationBar {
    private static var _style = [String: Style<UINavigationBar>]()

    public var style: Style<UINavigationBar> {
        get {
            let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
            return UINavigationBar._style[tmpAddress] ?? NavigationBarStyles.default
        } set {
            let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
            UINavigationBar._style[tmpAddress] = newValue
            newValue.apply(to: self)
        }
    }
}

extension UINavigationController {
    public convenience init(rootViewController: UIViewController, style: Style<UINavigationBar>) {
        self.init(rootViewController: rootViewController)
        self.navigationBar.style = style
    }
}
