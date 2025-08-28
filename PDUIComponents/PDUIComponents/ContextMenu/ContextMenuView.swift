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
import PDLocalization

public struct ContextMenuView<Label: View, Content: View, Modifier: ViewModifier>: View {

    private let labelView: Label
    private let color: Color?
    private let viewModifier: Modifier
    private let content: Content

    public init(
        icon: Image,
        color: Color = ColorProvider.TextNorm,
        viewModifier: Modifier,
        @ViewBuilder content: () -> Content
    ) where Label == Image {
        self.color = color
        self.labelView = icon // The Label is an Image
        self.viewModifier = viewModifier
        self.content = content()
    }
    
    public init(
        color: Color = ColorProvider.TextNorm,
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    ) where Modifier == EmptyModifier {
        self.color = color
        self.labelView = label()
        self.viewModifier = EmptyModifier()
        self.content = content()
    }

    public var body: some View {
        Menu {
            content
        } label: {
            labelView
                .tint(color)       // Remove if you don’t need automatic coloring
                .modifier(viewModifier)
        }
    }
}

struct ContextMenuView_Previews: PreviewProvider {
    static var previews: some View {
        ContextMenuView(icon: IconProvider.plus, viewModifier: EmptyModifier()) {
            Button(action: {}) {
                Label(Localization.general_rename, image: "ic-text-font")
            }
            Button(action: {}) {
                Label(Localization.edit_section_remove, image: "ic-trash")
            }
        }
    }
}
