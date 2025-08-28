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
public struct ActionBar<Content: View, ContextMenu: View>: View {

    @Binding var selection: ActionBarButtonViewModel?

    private let content: Content

    private let items: [ActionBarButtonViewModel]
    private let leadingItems: [ActionBarButtonViewModel]
    private let trailingItems: [ActionBarButtonViewModel]
    private let isLoading: Bool
    private let isContainedInVStack: Bool
    private var contextMenu: ((ActionBarButtonViewModel) -> ContextMenu)?

    public init(
        onSelection: @escaping (ActionBarButtonViewModel?) -> Void,
        items: [ActionBarButtonViewModel] = [],
        leadingItems: [ActionBarButtonViewModel] = [],
        trailingItems: [ActionBarButtonViewModel] = [],
        isLoading: Bool = false,
        isContainedInVStack: Bool = false,
        @ViewBuilder content: () -> Content,
        contextMenu: @escaping ((ActionBarButtonViewModel) -> ContextMenu) = { _ in EmptyView() }
    ) {
        self._selection = .init(get: { nil }, set: onSelection) // because .onChange is not available on iOS 13
        self.items = items
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.isLoading = isLoading
        self.isContainedInVStack = isContainedInVStack
        self.content = content()
        self.contextMenu = contextMenu
    }

    public init(
        onSelection: @escaping (ActionBarButtonViewModel?) -> Void,
        items: [ActionBarButtonViewModel] = [],
        leadingItems: [ActionBarButtonViewModel] = [],
        trailingItems: [ActionBarButtonViewModel] = [],
        isLoading: Bool = false,
        isContainedInVStack: Bool = false,
        contextMenu: @escaping ((ActionBarButtonViewModel) -> ContextMenu) = { _ in EmptyView() }
    ) where Content == EmptyView {
        self.init(
            onSelection: onSelection,
            items: items,
            leadingItems: leadingItems,
            trailingItems: trailingItems,
            isLoading: isLoading,
            isContainedInVStack: isContainedInVStack,
            content: EmptyView.init,
            contextMenu: contextMenu
        )
    }

    public var body: some View {
        if isContainedInVStack {
            ZStack(alignment: .bottom) {
                contentView
            }
        } else {
            VStack {
                Spacer()
                contentView
            }
        }
    }

    private var contentView: some View {
        VStack {
            Divider()
            innerView
                .frame(height: ActionBarSize.height)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(ColorProvider.BackgroundNorm)
        
    }

    @ViewBuilder
    private var innerView: some View {
        ActionBarRow(selection: self.$selection,
                     items: self.items,
                     leadingItems: self.leadingItems,
                     trailingItems: self.trailingItems,
                     content: { self.content },
                     contextMenu: contextMenu,
                     isLoading: isLoading
        )
    }
}

public extension Notification.Name {
    static var actionBarVisibilityIsChanged: Notification.Name {
        Notification.Name("ch.protondrive.actionBar.visibility.changed")
    }
}
#endif
