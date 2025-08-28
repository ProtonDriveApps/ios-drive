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

import Foundation
import SwiftUI

public struct GetHeightModifier: ViewModifier {
    @Binding var height: CGFloat
    var color: Color

    public init(height: Binding<CGFloat>, color: Color = .clear) {
        self._height = height
        self.color = color
    }

    public func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    height = geo.size.height
                }
                return color
            }
        )
    }
}

public struct GetWidthModifier: ViewModifier {
    @Binding var width: CGFloat
    var color: Color

    public init(width: Binding<CGFloat>, color: Color = .clear) {
        self._width = width
        self.color = color
    }

    public func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    width = geo.size.width
                }
                return color
            }
        )
    }
}

public struct GetSafeAreaInsetsModifier: ViewModifier {
    @Binding var safeAreaInsets: EdgeInsets
    var color: Color

    public init(safeAreaInsets: Binding<EdgeInsets>, color: Color = .clear) {
        self._safeAreaInsets = safeAreaInsets
        self.color = color
    }

    public func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    safeAreaInsets = geo.safeAreaInsets
                }
                return color
            }
        )
    }
}
