//
//  PMBannerPosition.swift
//  ProtonCore-UIFoundations - Created on 31.08.20.
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

public enum PMBannerPosition {
    case top
    case bottom
    case topCustom(UIEdgeInsets)
    case bottomCustom(UIEdgeInsets)

    public var edgeInsets: UIEdgeInsets {
        switch self {
        case .top:
            return UIEdgeInsets(top: 8, left: 16, bottom: CGFloat.infinity, right: 16)
        case .bottom:
            return UIEdgeInsets(top: CGFloat.infinity, left: 8, bottom: 21, right: 8)
        case .topCustom(let insets):
            return insets
        case .bottomCustom(let insets):
            return insets
        }
    }
}
