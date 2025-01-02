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

public struct ActionBarSize {
    public static let height: CGFloat = 40
}

#if os(iOS)
public struct ActionBar<Content: View>: View {
    
    @Binding var selection: ActionBarButtonViewModel?

    private let content: Content

    private let items: [ActionBarButtonViewModel]
    private let leadingItems: [ActionBarButtonViewModel]
    private let trailingItems: [ActionBarButtonViewModel]
    
    public init(onSelection: @escaping (ActionBarButtonViewModel?) -> Void,
                items: [ActionBarButtonViewModel] = [],
                leadingItems: [ActionBarButtonViewModel] = [],
                trailingItems: [ActionBarButtonViewModel] = [],
                @ViewBuilder content: () -> Content) {
        self._selection = .init(get: { nil }, set: onSelection) // because .onChange is not available on iOS 13
        self.items = items
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.content = content()
    }

    public init(onSelection: @escaping (ActionBarButtonViewModel?) -> Void,
                items: [ActionBarButtonViewModel] = [],
                leadingItems: [ActionBarButtonViewModel] = [],
                trailingItems: [ActionBarButtonViewModel] = []) where Content == EmptyView {
        self.init(
            onSelection: onSelection,
            items: items,
            leadingItems: leadingItems,
            trailingItems: trailingItems,
            content: EmptyView.init
        )
    }

    public var body: some View {
        VStack {
            Spacer()
            VStack {
                Divider()
                ActionBarRow(selection: self.$selection,
                             items: self.items,
                             leadingItems: self.leadingItems,
                             trailingItems: self.trailingItems,
                             content: { self.content }
                )
                .frame(height: ActionBarSize.height)
            }
            .background(ColorProvider.BackgroundNorm)
        }
    }
}
#endif
