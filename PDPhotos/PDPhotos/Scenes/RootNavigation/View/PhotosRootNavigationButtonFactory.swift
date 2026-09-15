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

import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents
import PDCore

extension PhotosRootNavigation.Item {
    var hidesToolbarSharedBackground: Bool {
        if case .subscribe = self {
            return true
        }
        return false
    }
}

final class PhotosRootNavigationButtonFactory {
    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    func makeGlassToolbar(
        navigation: PhotosRootNavigation?,
        block: @escaping (PhotosRootNavigation.Item) -> Void
    ) -> some ToolbarContent {
        if let navigation, let title = navigation.title {
            makeToolbarTitle(title: title)
            navigation.leading.map {
                makeGlassToolbarItems(items: [$0], placement: .topBarLeading, block: block)
            }
            makeGlassToolbarItems(items: navigation.trailing, placement: .topBarTrailing, block: block)
        }
    }

    @ToolbarContentBuilder
    func makeLegacyToolbar(
        navigation: PhotosRootNavigation?,
        block: @escaping (PhotosRootNavigation.Item) -> Void
    ) -> some ToolbarContent {
        if let navigation, let title = navigation.title {
            makeToolbarTitle(title: title)
            navigation.leading.map {
                makeLegacyToolbarItems(items: [$0], placement: .topBarLeading, block: block)
            }
            makeLegacyToolbarItems(items: navigation.trailing, placement: .topBarTrailing, block: block)
        }
    }

    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    func makeGlassToolbarItems(
        items: [PhotosRootNavigation.Item],
        placement: ToolbarItemPlacement,
        block: @escaping (PhotosRootNavigation.Item) -> Void
    ) -> some ToolbarContent {
        spacedToolbarItems(
            items,
            placement: placement,
            hidesSharedBackground: \.hidesToolbarSharedBackground
        ) { item in
            self.makeButton(item: item, block: block).any()
        }
    }

    @ToolbarContentBuilder
    func makeLegacyToolbarItems(
        items: [PhotosRootNavigation.Item],
        placement: ToolbarItemPlacement,
        block: @escaping (PhotosRootNavigation.Item) -> Void
    ) -> some ToolbarContent {
        plainToolbarItems(items, placement: placement) { item in
            self.makeButton(item: item, block: block).any()
        }
    }

    func makeToolbarTitle(title: String) -> ToolbarItem<(), Text> {
        ToolbarItem(placement: .principal) {
            Text(title)
                .bold()
        }
    }

    @ViewBuilder
    func makeButton(item: PhotosRootNavigation.Item, block: @escaping (PhotosRootNavigation.Item) -> Void) -> any View {
        switch item {
        case .cross:
            Button {
                block(item)
            } label: {
                Image(uiImage: IconProvider.crossBig)
                    .resizable()
                    .foregroundStyle(ColorProvider.IconNorm)
                    .frame(width: 24, height: 24)
            }
            .accessibility(identifier: "PhotosRootView.NavigationBarButton.Cross")
        case .menu:
            MenuButton {
                block(item)
            }
        case .plus:
            Button {
                block(item)
            } label: {
                Image(uiImage: IconProvider.plus)
                    .resizable()
                    .foregroundStyle(ColorProvider.IconNorm)
                    .frame(width: 24, height: 24)
            }
            .accessibility(identifier: "PhotosRootView.NavigationBarButton.Plus")
        case let .cancel(title):
            TextNavigationBarButton(title: title, weight: .bold) {
                block(item)
            }
            .accessibility(identifier: "PhotosRootView.NavigationBarButton.Cancel")
            .fixedSize()
            .padding(.horizontal, 8)
        case let .deselectAll(title, isEnabled):
            TextNavigationBarButton(title: title, weight: .bold) {
                block(item)
            }
            .disabled(!isEnabled)
            .accessibility(identifier: "PhotosRootView.NavigationBarButton.DeselectAll")
            .fixedSize()
            .padding(.horizontal, 8)
        case .subscribe:
            SubscriptionBarItem(identifier: "PhotosRootView.NavigationBarButton.Subscription") {
                block(item)
            }
            .if(!PDCore.Constants.buildFeatures.hasPayments) { button in
                button
                    .disabled(true)
                    .opacity(0.4)
            }
        case .tagMigrationSpinner:
            ProtonSpinner(size: .custom(24))
                .onTapGesture {
                    block(item)
                }
        }
    }
}
