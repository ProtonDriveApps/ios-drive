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
extension UINavigationBarAppearance {
    private static var textColor: UIColor { ColorProvider.TextNorm }
    private static var backgroundColor: UIColor { ColorProvider.BackgroundNorm }
    private static var backIcon: UIImage { IconProvider.arrowLeft.withTintColor(textColor, renderingMode: .alwaysOriginal) }

    static var drive: UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()

        // Apply a BackgroundNorm background.
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear

        // Configure back indicator
        appearance.setBackIndicatorImage(backIcon, transitionMaskImage: backIcon)
        appearance.backButtonAppearance = .clear

        // Apply TextNorm colored normal and large titles.
        appearance.titleTextAttributes = [.foregroundColor: textColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: textColor]

        // Apply Proton colors to all the nav bar buttons.
        appearance.buttonAppearance = .default
        appearance.doneButtonAppearance = .default

        return appearance
    }
}

extension UIBarButtonItemAppearance {
    static var clear: UIBarButtonItemAppearance {
        let appearance = UIBarButtonItemAppearance(style: .plain)
        appearance.normal.titleTextAttributes = [.font: UIFont.systemFont(ofSize: .zero), .foregroundColor: UIColor.clear]
        appearance.focused.titleTextAttributes = [.font: UIFont.systemFont(ofSize: .zero), .foregroundColor: UIColor.clear]
        appearance.highlighted.titleTextAttributes = [.font: UIFont.systemFont(ofSize: .zero), .foregroundColor: UIColor.clear]
        return appearance
    }

    static var `default`: UIBarButtonItemAppearance {
        let appearance = UIBarButtonItemAppearance()
        appearance.normal.titleTextAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .headline).bold(),
            .foregroundColor: UIColor(ColorProvider.TextAccent)
        ]
        appearance.highlighted.titleTextAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .headline).bold(),
            .foregroundColor: UIColor(ColorProvider.InteractionNormPressed)
        ]
        appearance.disabled.titleTextAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .headline).bold(),
            .foregroundColor: UIColor(ColorProvider.TextDisabled)
        ]
        return appearance
    }
}
#endif
