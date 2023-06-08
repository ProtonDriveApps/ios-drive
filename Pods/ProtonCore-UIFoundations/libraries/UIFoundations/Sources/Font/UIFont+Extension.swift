//
//  UIFont+Extension.swift
//  ProtonCore-UIFoundations - Created on 20.07.22.
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

extension UIFont {
    public static func preferredFont(for style: TextStyle, weight: Weight) -> UIFont {
        let trait = UITraitCollection(preferredContentSizeCategory: .large)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: trait)
        let font = UIFont.systemFont(ofSize: desc.pointSize, weight: weight)
        let limit = UIFont.fontLimit(for: style)

        let metrics = UIFontMetrics(forTextStyle: style)
        if DFSSetting.limitToXXXLarge {
            return metrics.scaledFont(for: font, maximumPointSize: limit, compatibleWith: trait)
        } else {
            let result = metrics.scaledFont(for: font, compatibleWith: trait)
            return result
        }
    }

    public static func adjustedFont(
        forTextStyle style: TextStyle,
        weight: Weight = .regular,
        fontSize: CGFloat? = nil
    ) -> UIFont {
        if DFSSetting.enableDFS {
            return .preferredFont(for: style, weight: weight)
        } else {
            let pointSize = UIFont.defaultPointSize(forTextStyle: style)
            let size = fontSize ?? pointSize
            return .systemFont(ofSize: size, weight: weight)
        }
    }

    // From Apple document
    // https://developer.apple.com/design/human-interface-guidelines/foundations/typography/#dynamic-type-sizes
    // Large (Default)
    private static func defaultPointSize(forTextStyle style: TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:
            return 34
        case .title1:
            return 28
        case .title2:
            return 22
        case .title3:
            return 20
        case .headline:
            return 17
        case .subheadline:
            return 15
        case .body:
            return 17
        case .callout:
            return 16
        case .footnote:
            return 13
        case .caption1:
            return 12
        case .caption2:
            return 11
        default:
            return 17
        }
    }

    // From Apple document
    // https://developer.apple.com/design/human-interface-guidelines/foundations/typography/#dynamic-type-sizes
    // xxxLarge
    public static func fontLimit(for style: TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:
            return 40
        case .title1:
            return 34
        case .title2:
            return 28
        case .title3:
            return 26
        case .headline:
            return 23
        case .body:
            return 23
        case .callout:
            return 22
        case .subheadline:
            return 21
        case .footnote:
            return 19
        case .caption1:
            return 18
        case .caption2:
            return 17
        default:
            return 23
        }
    }
}
