//
//  UIDevice+Info.swift
//  ProtonCore-UIFoundations - Created on 23.07.20.
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
public extension UIDevice {
    /// A boolean value that indicates the device has a physical home button or not.
    static var hasPhysicalHome: Bool {
        guard #available(iOS 11.0, *) else {
            // Device that under iOS 11 must have physical home button
            return true
        }

        guard let application = UIApplication.getInstance(),
              let keyWindow = application.windows.first,
              keyWindow.safeAreaInsets.bottom > 0 else {
            // Device has physical home button
            return true
        }
        return false
    }

    /// Return `safeAreaInsets` of the device.
    /// Compatible with iOS lower than `11.0`
    static let safeGuide: UIEdgeInsets = {
        guard #available(iOS 11.0, *) else {
            // Device has physical home button
            return .zero
        }
        guard let application = UIApplication.getInstance(),
              let keyWindow = application.windows.first else {
            // Device has physical home button
            return .zero
        }
        return keyWindow.safeAreaInsets
    }()
}
