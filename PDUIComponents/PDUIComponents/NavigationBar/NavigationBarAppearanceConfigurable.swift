// Copyright (c) 2025 Proton AG
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

#if os(iOS)
import Foundation
import UIKit

public protocol NavigationBarAppearanceConfigurable: AnyObject {
    var navigationController: UINavigationController? { get }
    var defaultBarAppearance: NavigationBarAppearance? { get set }

    func storeDefaultAppearance()
    func setUpAppearance(_ appearance: NavigationBarAppearance?)
}

extension NavigationBarAppearanceConfigurable {
    public func storeDefaultAppearance() {
        guard let bar = navigationController?.navigationBar else { return }

        defaultBarAppearance = NavigationBarAppearance(
            standardAppearance: bar.standardAppearance,
            compactAppearance: bar.compactAppearance,
            scrollEdgeAppearance: bar.scrollEdgeAppearance,
            isTranslucent: bar.isTranslucent
        )
    }

    public func setUpAppearance(_ appearance: NavigationBarAppearance?) {
        guard let appearance,
              let bar = navigationController?.navigationBar
        else { return }

        bar.standardAppearance = appearance.standardAppearance
        bar.compactAppearance = appearance.compactAppearance
        bar.scrollEdgeAppearance = appearance.scrollEdgeAppearance
        bar.isTranslucent = appearance.isTranslucent

        // Force an immediate update
        bar.setNeedsLayout()
        bar.layoutIfNeeded()
    }
}
#endif
