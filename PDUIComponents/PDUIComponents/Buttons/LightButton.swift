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

public struct LightButton: View {
    var title: String
    var color: Color
    var disabledColor: Color
    var font: Font
    var action: () -> Void
    
    public init(title: String,
                color: Color = ColorProvider.TextWeak,
                disabledColor: Color = ColorProvider.TextDisabled,
                font: Font = .footnote,
                action: @escaping () -> Void)
    {
        self.title = title
        self.color = color
        self.disabledColor = disabledColor
        self.font = font
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
        }
        .buttonStyle(LightButtonStyle(color: color, disabledColor: disabledColor))
    }
}

struct LightButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LightButton(title: "Need help?", action: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.light)
            
            LightButton(title: "Need help?", action: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.dark)
            
            LightButton(title: "Need help?", action: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.light)
                .disabled(true)
            
            LightButton(title: "Need help?", action: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.dark)
                .disabled(true)
        }
        .previewLayout(.sizeThatFits)
    }
}

private struct LightButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var color: Color
    var disabledColor: Color
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? color : disabledColor)
    }
}
