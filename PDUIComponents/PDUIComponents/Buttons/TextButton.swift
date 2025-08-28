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
public struct TextButton: View {
    let title: String
    let variant: ButtonVariant
    let padding: ViewPadding
    let action: () -> Void

    public init(title: String, variant: ButtonVariant = .regular, padding: ViewPadding = .default, action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.padding = padding
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(TextButtonStyle(variant: variant, padding: padding))
    }
}
#endif
