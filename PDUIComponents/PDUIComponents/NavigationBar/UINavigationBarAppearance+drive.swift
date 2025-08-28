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
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear

        appearance.setBackIndicatorImage(backIcon, transitionMaskImage: backIcon)
        appearance.backButtonAppearance = .clear

        appearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFont(for: .body, weight: .semibold)
        ]

        appearance.buttonAppearance = .default
        appearance.doneButtonAppearance = .default

        return appearance
    }

    public static func transparent() -> NavigationBarAppearance {
        let driveAppearance = UINavigationBarAppearance()
        driveAppearance.configureWithTransparentBackground()
        driveAppearance.backgroundColor = .clear
        driveAppearance.shadowColor = .clear
        driveAppearance.backgroundImage = UIImage()
        driveAppearance.shadowColor = .clear
        driveAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]

        let backIcon: UIImage = IconProvider.arrowLeft.withTintColor(
            ColorProvider.IconNorm,
            renderingMode: .alwaysOriginal
        )
        driveAppearance.setBackIndicatorImage(backIcon, transitionMaskImage: backIcon)
        driveAppearance.backButtonAppearance = .clear
        return .init(
            standardAppearance: driveAppearance,
            compactAppearance: driveAppearance,
            scrollEdgeAppearance: driveAppearance,
            isTranslucent: true
        )
    }
}

public extension UIBarButtonItemAppearance {
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
