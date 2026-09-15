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
import ProtonCoreUIFoundations

private struct ExampleView: View {
    @State var selected: GalleryType = .photos
    var body: some View {
        Text("hi")
            .toolbar {
                NavigationTitleView().title(isEnabled: false, selected: $selected)
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Done")
                }
                ToolbarItem(placement: .topBarLeading) {
                    IconProvider.hamburger
                }
            }
    }
}

#Preview {
    NavigationView {
        ExampleView(selected: .photos)
    }
}

public struct NavigationTitleView {
    public init() {}

    @ToolbarContentBuilder
    public func title(isEnabled: Bool, placement: ToolbarItemPlacement = .automatic, selected: Binding<GalleryType>) -> some ToolbarContent {
        ToolbarItem(placement: placement) {
            HStack(spacing: 12) {
                text(tag: .photos, selected: selected)
                    .onTapGesture {
                        selected.wrappedValue = .photos
                    }

                if isEnabled {
                    Divider()
                        .foregroundStyle(ColorProvider.SeparatorNorm)
                        .frame(height: 26)

                    text(tag: .albums, selected: selected)
                        .onTapGesture {
                            selected.wrappedValue = .albums
                        }
                }
            }
            .disabled(!isEnabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func text(tag: GalleryType, selected: Binding<GalleryType>) -> some View {
        let foreground: Color = selected.wrappedValue == tag ? ColorProvider.TextNorm : ColorProvider.TextHint
        Text(tag.title)
            .font(.headline)
            .foregroundStyle(foreground)
            .fontWeight(.bold)
            .accessibilityIdentifier("NavigationTitleView.Text.\(tag.title)")
    }
}
