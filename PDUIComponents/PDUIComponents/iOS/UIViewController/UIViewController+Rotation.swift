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
import UIKit

public extension UIViewController {
    private(set) static var orientationLock = UIInterfaceOrientationMask.allButUpsideDown

    func lockOrientationIfNeeded(in orientation: UIInterfaceOrientationMask) {
        Self.lockOrientationIfNeeded(in: orientation)
    }

    static func lockOrientationIfNeeded(in orientation: UIInterfaceOrientationMask) {
        if UIDevice.current.userInterfaceIdiom == .phone {
            UIViewController.orientationLock = orientation
        }
    }
}
#endif
