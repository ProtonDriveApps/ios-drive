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

import UIKit
import ProtonCoreUIFoundations

public extension UIBarButtonItem {
    static func back(on target: Any?, action: Selector) -> UIBarButtonItem {
        return makeButton(on: target, action: action, image: IconProvider.arrowLeft)
    }

    static func close(on target: Any?, action: Selector) -> UIBarButtonItem {
        return makeButton(on: target, action: action, image: IconProvider.cross)
    }

    static func button(on target: Any?, action: Selector, image: UIImage?) -> UIBarButtonItem {
        return makeButton(on: target, action: action, image: image)
    }

    private static func makeButton(on target: Any?, action: Selector, image: UIImage?) -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.tintColor = ColorProvider.IconNorm
        button.setImage(image, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        if #available(iOS 26.0, *) {
            button.setSizeContraint(height: 24, width: 24)
        } else {
            // UIBarButtonItem(customView:) doesn't get the system 44pt minimum touch target,
            // so enforce it on pre-26 bars; the image keeps its intrinsic 24pt size.
            button.setSizeContraint(height: 44, width: 44)
        }
        return UIBarButtonItem(customView: button)
    }
}
