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

public struct ProgressBar: View {
    public init(value: Binding<Double>, offset: CGFloat = 0, foregroundColor: Color = Color.BrandNorm, backgroundColor: Color = ColorProvider.TextWeak) {
        self._value = value
        self.offset = offset
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    @Binding var value: Double
    var offset: CGFloat
    var foregroundColor: Color = Color.BrandNorm
    var backgroundColor: Color = ColorProvider.TextWeak
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
                    .foregroundColor(self.backgroundColor)
                    .cornerRadius(.circled)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width),
                           height: geometry.size.height)
                    .foregroundColor(self.foregroundColor)
                    .animation(.linear)
                    .cornerRadius(.circled)
            }
        }
        .padding(.leading, self.offset)
    }
}

struct ProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        ProgressBar(value: .constant(0.7), offset: 0.0)
            .padding()
            .previewLayout(.fixed(width: 300, height: 40))
        
    }
}
