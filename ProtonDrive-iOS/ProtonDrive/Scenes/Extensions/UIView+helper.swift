// Copyright (c) 2024 Proton AG
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

extension UIView {
    // when orientation change, screen can't provide correct size immediately
    // Use this workaround to get correct size 
    func realScreenSize() -> CGSize? {
        guard let scene = window?.windowScene else { return nil }
        let screen = scene.screen
        
        let lengthA = screen.bounds.height
        let lengthB = screen.bounds.width
        let screenWidth = scene.interfaceOrientation.isPortrait ? min(lengthA, lengthB) : max(lengthA, lengthB)
        let screenHeight = screenWidth == lengthA ? lengthB : lengthA
        return .init(width: screenWidth, height: screenHeight)
    }
}
