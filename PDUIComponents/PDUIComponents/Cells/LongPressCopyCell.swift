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

#if os(iOS)
public struct LongPressCopyCell: View {
    private let text: String
    private let image: Image?
    private let onLongPress: () -> Void

    public init(text: String, image: Image?, onLongPress: @escaping () -> Void) {
        self.text = text
        self.image = image
        self.onLongPress = onLongPress
    }

    public var body: some View {
        LongPressCell(onLongPress: onLongPress) {
            HStack {
                Text(text)
                    .foregroundColor(ColorProvider.TextNorm)
                    .lineLimit(1)
                    .accessibility(identifier: "LongPressCopyCell.Text.SecureLink")

                Spacer()

                if let image = image {
                    image
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(ColorProvider.IconNorm)
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: onLongPress)
                        .accessibility(identifier: "LongPressCopyCell.Text.Image")
                }
            }
        }
    }
}
#endif
