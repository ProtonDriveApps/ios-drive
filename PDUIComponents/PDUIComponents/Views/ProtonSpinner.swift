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
import ProtonCoreUIFoundations

public struct ProtonSpinner: View {
    public enum Size {
        case small
        case medium
        case custom(Double)
        
        var aspect: CGFloat {
            switch self {
            case .small: return 0.7
            case .medium: return 1.5
            case let .custom(size): return CGFloat(size) / 24
            }
        }
    }
    
    public enum Style {
        case regular
        case inverted
    }
    
    private let aspect: CGFloat
    private let style: Style
    
    public init(size: Size, style: Style = .regular) {
        self.aspect = size.aspect
        self.style = style
    }

    public var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
            .scaleEffect(aspect)
            .padding(0)
    }

    private var primaryColor: Color {
        style == .regular ? Color.BrandNorm : .white
    }
}

struct ProtonSpinner_Previews: PreviewProvider {
    static var previews: some View {
        ProtonSpinner(size: .custom(100))
            .previewLayout(.sizeThatFits)
    }
}
