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

public struct BlueRectButton: View {
    @Environment(\.isEnabled) var isEnabled
    var title: String
    var foregroundColor: Color
    var backgroundColor: Color
    var font: Font
    var height: CGFloat
    var cornerRadius: CornerRadius
    var action: () -> Void
    
    public init(title: String,
                foregroundColor: Color = Color.white,
                backgroundColor: Color = Color.BrandNorm,
                font: Font = .body,
                height: CGFloat = 48.0,
                cornerRadius: CornerRadius = .small,
                action: @escaping () -> Void)
    {
        self.title = title
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.font = font
        self.height = height
        self.cornerRadius = cornerRadius
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                self.backgroundColor
                    .cornerRadius(cornerRadius)
                
                Text(title)
                    .font(self.font)
                    .foregroundColor(self.foregroundColor)
                    .padding(.horizontal)
            }
            .frame(maxWidth: 400)
            .frame(height: self.height, alignment: .center)
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BlueRectButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BlueRectButton(title: "Start", action: { })
                .padding()
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.light)
            
            BlueRectButton(title: "Start", action: { })
                .padding()
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.dark)
        }
        .previewLayout(.sizeThatFits)
        .environment(\.isEnabled, true)
    }
}
