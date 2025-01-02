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
extension UIToolbar {
    public static func setupApparance() {
        let globalAppearance = UIToolbar.appearance()
        let driveAppearance = makeAppearance()
        globalAppearance.scrollEdgeAppearance = driveAppearance
        globalAppearance.compactAppearance = driveAppearance
        globalAppearance.standardAppearance = driveAppearance
        globalAppearance.compactScrollEdgeAppearance = driveAppearance
    }

    private static func makeAppearance() -> UIToolbarAppearance {
        let appearance = UIToolbarAppearance()

        // Apply a BackgroundNorm background.
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ColorProvider.BackgroundNorm
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear

        // Apply Proton colors to all the nav bar buttons.
        appearance.buttonAppearance = .default

        return appearance
    }
}
#endif
