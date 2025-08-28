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
struct ActionBarRow<Content: View, ContextMenu: View>: View {
    @Binding var selection: ActionBarButtonViewModel?
    private let items: [ActionBarButtonViewModel]
    private let leadingItems: [ActionBarButtonViewModel]
    private let trailingItems: [ActionBarButtonViewModel]
    private let content: Content
    private var contextMenu: ((ActionBarButtonViewModel) -> ContextMenu)?
    private let isLoading: Bool

    public init(
        selection: Binding<ActionBarButtonViewModel?>,
        items: [ActionBarButtonViewModel] = [],
        leadingItems: [ActionBarButtonViewModel] = [],
        trailingItems: [ActionBarButtonViewModel] = [],
        @ViewBuilder content: () -> Content,
        contextMenu: ((ActionBarButtonViewModel) -> ContextMenu)?,
        isLoading: Bool
    ) {
        self._selection = selection
        self.items = items
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.content = content()
        self.contextMenu = contextMenu
        self.isLoading = isLoading
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(self.leadingItems) {
                ActionBarButtonView(vm: $0, selection: self.$selection, contextMenu: contextMenu)
                    .environment(\.layoutDirection, .leftToRight)
                    .fixedSize()
                    .opacity(opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if !self.items.isEmpty {
                HStack {
                    ForEach(self.items) {
                        ActionBarButtonView(vm: $0, selection: self.$selection, contextMenu: contextMenu)
                            .opacity(opacity)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)

                    content
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 20, maxHeight: .infinity)
                }

            } else {
                Spacer()
                    .frame(width: 80)
            }
            
            ForEach(self.trailingItems) {
                ActionBarButtonView(vm: $0, selection: self.$selection, contextMenu: contextMenu)
                    .opacity(opacity)
                .environment(\.layoutDirection, .rightToLeft)
                .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

        }
    }

    private var opacity: Double {
        isLoading ? 0.3 : 1
    }
}

#Preview {
    ActionBarRow(
        selection: .constant(.createFolder),
        leadingItems: [.cancel],
        trailingItems: [.createFolder],
        content: { Text("hi") },
        contextMenu: { _ in Text("hi") },
        isLoading: false
    )
}
#endif
