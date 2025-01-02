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


import ProtonCoreUIFoundations
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
public extension UIBarButtonItem {
    static func back(on target: Any?, action: Selector) -> UIBarButtonItem {
        return button(on: target, action: action, image: IconProvider.arrowLeft)
    }

    static func close(on target: Any?, action: Selector) -> UIBarButtonItem {
        let button = button(on: target, action: action, image: IconProvider.cross)
        button.accessibilityIdentifier = "Button.Close"
        return button
    }

    static func button(on target: Any?, action: Selector, image: UIImage?) -> UIBarButtonItem {
        let button = UIButton(frame: .zero)
        button.setSizeContraint(height: 24, width: 24)
        button.tintColor = ColorProvider.IconNorm
        button.setBackgroundImage(image, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }

    static func systemButton(imageName: String, target: Any?, action: Selector) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: imageName), style: .plain, target: target, action: action)
        item.tintColor = ColorProvider.IconNorm
        return item
    }

    static func button(on target: Any?, action: Selector, text: String) -> UIBarButtonItem {
        let button = UIButton(frame: .zero)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.setTitleColor(ColorProvider.TextAccent, for: .normal)
        button.setTitleColor(ColorProvider.TextDisabled, for: .disabled)
        button.setTitleColor(ColorProvider.InteractionNormPressed, for: .highlighted)
        button.addTarget(target, action: action, for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }
}
#endif
