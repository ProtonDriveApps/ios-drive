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
public struct LongPressCell<Content: View>: View {
    let onTap: () -> Void
    let onLongPress: () -> Void
    let content: () -> Content

    public init(
        onTap: @escaping () -> Void = {},
        onLongPress: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.content = content
    }

    public var body: some View {
        Button {
            
        } label: {
            content()
                .onTapGesture(perform: onTap)
                .onLongPressGesture(perform: onLongPress)
        }
        .buttonStyle(HighlightableButtonStyle())

    }
}
#endif
