//
//  UIView+helper.swift
//  ProtonCore-UIFoundations - Created on 03.08.20.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import UIKit
public extension UIView {
    var safeGuide: UIEdgeInsets {
        guard #available(iOS 11.0, *) else {
            // Device has physical home button
            return UIEdgeInsets.zero
        }
        return self.safeAreaInsets
    }

    func roundCorner(_ radius: CGFloat) {
        self.layer.cornerRadius = radius
        self.layer.masksToBounds = true
    }

    func getKeyboardHeight() -> CGFloat {

        guard let application = UIApplication.getInstance() else {
            return 0
        }

        let keyboardWindow = application.windows.first(where: {
            let desc = $0.description.lowercased()
            return desc.contains("keyboard")
        })
        guard let rootVC = keyboardWindow?.rootViewController else {
            return 0
        }
        for sub in rootVC.view.subviews {
            guard sub.description.contains("UIInputSetHostView") else {
                continue
            }
            return sub.frame.size.height
        }
        return 0
    }
    
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: frame.size)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
}
