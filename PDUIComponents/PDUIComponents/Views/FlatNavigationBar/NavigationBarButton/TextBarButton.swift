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

public struct TextBarButton: View {
    @Environment(\.isEnabled) private var isEnabled

    let text: String
    let action: () -> Void

    public init(text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(text)
                .font(Font.headline.weight(.semibold))
                .foregroundColor(Color.BrandNorm)
                .opacity(isEnabled ? 1 : 0.25)
        }
    }
}

struct TextBarButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TextBarButton(text: "Done", action: {})
                .padding()
                .disabled(false)
                .previewLayout(.sizeThatFits)

            TextBarButton(text: "Done", action: {})
                .padding()
                .disabled(true)
                .previewLayout(.sizeThatFits)

            TextBarButton(text: "Done", action: {})
                .padding()
                .preferredColorScheme(.dark)
                .disabled(false)
                .previewLayout(.sizeThatFits)

            TextBarButton(text: "Done", action: {})
                .padding()
                .preferredColorScheme(.dark)
                .disabled(true)
                .previewLayout(.sizeThatFits)
        }
    }
}
