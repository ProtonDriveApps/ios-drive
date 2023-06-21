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

import SwiftUI

public enum CornerRadius: CGFloat {
    case circled = 0
    case small = 2 // max 48px height
    case medium = 4 // max 128px height
    case large = 6 // min 320px height
    case huge = 8
    case extraHuge = 12
}

public extension View {
    #if canImport(UIKit)
    func cornerRadius(_ radius: CornerRadius, corners: UIRectCorner? = nil) -> some View {
        clipShape( RoundedCorner(radius: radius.rawValue, corners: corners) )
    }
    #elseif canImport(AppKit)
    func cornerRadius(_ radius: CornerRadius) -> some View {
        clipShape( RoundedCorner(radius: radius.rawValue) )
    }
    #endif
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    
    #if canImport(UIKit)
    var corners: UIRectCorner?
    #endif

    func path(in rect: CGRect) -> Path {
        let radius = self.radius == 0 ? .infinity : self.radius
        let radii = CGSize(width: radius, height: radius)
        
        #if canImport(UIKit)
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners ?? .allCorners,
                                cornerRadii: radii)
        return Path(path.cgPath)
        #elseif canImport(AppKit)
        let path = CGPath(roundedRect: rect, cornerWidth: radii.width, cornerHeight: radii.height, transform: nil)
        return Path(path)
        #endif
        
    }
}
