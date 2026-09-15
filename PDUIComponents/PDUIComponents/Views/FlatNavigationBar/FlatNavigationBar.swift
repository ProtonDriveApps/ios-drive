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

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
extension UINavigationBar {
    public static func setupFlatNavigationBarSystemWide() {
        let globalAppearance = UINavigationBar.appearance()
        let driveAppearance = UINavigationBarAppearance.drive

        globalAppearance.scrollEdgeAppearance = driveAppearance
        globalAppearance.compactAppearance = driveAppearance
        globalAppearance.standardAppearance = driveAppearance
        globalAppearance.compactScrollEdgeAppearance = driveAppearance
    }
}

// MARK: - Why availability is checked at the `View` level
//
// `if #available` must never appear *inside* a `@ToolbarContentBuilder` whose branch yields
// `CustomizableToolbarContent` (`ToolbarSpacer`, `.sharedBackgroundVisibility(_:)`, …).
// Doing so makes the compiler reference
//
//   opaque type descriptor for ToolbarContentBuilder.buildLimitedAvailability(some CustomizableToolbarContent)
//
// which SwiftUI never exports (it is inlinable — the symbol is absent from SwiftUI.tbd), so the
// app fails to link with "Undefined symbols for architecture arm64".
//
// The pattern used here instead: each toolbar builder is *wholly* gated with `@available`, so it
// may use the iOS 26 APIs unconditionally, and the choice between the iOS 26 and legacy builders
// happens in a `@ViewBuilder` context — which uses the back-deployed `ViewBuilder`
// `buildLimitedAvailability` overload and links fine.

public extension View {
    func flatNavigationBar<L, T>(
        _ title: String,
        leading: L?,
        trailing: T?
    ) -> some View where L: View, T: View {
        let modifier = NavigationBarModifier(title: title, leading: leading, trailing: trailing)
        return ModifiedContent(content: self, modifier: modifier)
    }

    /// Applies the navigation title plus a Liquid Glass–aware trailing toolbar built from `trailingItems`.
    ///
    /// On iOS 26 the items are emitted individually with fixed `ToolbarSpacer`s between them so each
    /// renders as its own Liquid Glass group; on earlier versions they are emitted as plain items.
    func flatNavigationBar<LeadingContent: View, ItemContent: View>(
        _ title: String,
        leading: LeadingContent?,
        trailingItems: [NavigationBarButton],
        @ViewBuilder trailingItem: @escaping (NavigationBarButton) -> ItemContent
    ) -> some View {
        let modifier = NavigationBarSpacedTrailingModifier(
            title: title,
            leading: leading,
            trailingItems: trailingItems,
            trailingItem: trailingItem
        )
        return ModifiedContent(content: self, modifier: modifier)
    }
}

public extension NavigationBarButton {
    var hidesToolbarSharedBackground: Bool {
        if case .subscribe = self {
            return true
        }
        return false
    }
}

struct NavigationBarModifier<L, T>: ViewModifier where L: View, T: View {
    let title: String
    let leading: L?
    let trailing: T?

    public func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                }

                ToolbarItem(placement: .topBarTrailing) {
                    trailing
                }
            }
    }
}

struct NavigationBarSpacedTrailingModifier<LeadingContent: View, ItemContent: View>: ViewModifier {
    let title: String
    let leading: LeadingContent?
    let trailingItems: [NavigationBarButton]
    @ViewBuilder let trailingItem: (NavigationBarButton) -> ItemContent

    @ViewBuilder
    func body(content: Content) -> some View {
        let titled = content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)

        if #available(iOS 26.0, *) {
            titled.toolbar {
                ToolbarItem(placement: .topBarLeading) { leading }
                spacedToolbarItems(
                    trailingItems,
                    placement: .topBarTrailing,
                    hidesSharedBackground: \.hidesToolbarSharedBackground,
                    content: trailingItem
                )
            }
        } else {
            titled.toolbar {
                ToolbarItem(placement: .topBarLeading) { leading }
                plainToolbarItems(trailingItems, placement: .topBarTrailing, content: trailingItem)
            }
        }
    }
}

@available(iOS 26.0, *)
@ToolbarContentBuilder
public func spacedToolbarItems<Item, ItemContent: View>(
    _ items: [Item],
    placement: ToolbarItemPlacement,
    hidesSharedBackground: (Item) -> Bool,
    @ViewBuilder content: (Item) -> ItemContent
) -> some ToolbarContent {
    if !items.isEmpty {
        spacedToolbarItem(items[0], placement: placement, hidesSharedBackground: hidesSharedBackground, content: content)
    }
    if items.count >= 2 {
        ToolbarSpacer(.fixed, placement: placement)
        spacedToolbarItem(items[1], placement: placement, hidesSharedBackground: hidesSharedBackground, content: content)
    }
    // Limit to at most 3; there isn’t enough space for more.
    if items.count >= 3 {
        ToolbarSpacer(.fixed, placement: placement)
        spacedToolbarItem(items[2], placement: placement, hidesSharedBackground: hidesSharedBackground, content: content)
    }
    if items.count > 3 {
        let _ = assertionFailure("There are too many toolbar buttons")
        ToolbarItem(placement: placement) { EmptyView() }
    }
}

@available(iOS 26.0, *)
@ToolbarContentBuilder
private func spacedToolbarItem<Item, ItemContent: View>(
    _ item: Item,
    placement: ToolbarItemPlacement,
    hidesSharedBackground: (Item) -> Bool,
    @ViewBuilder content: (Item) -> ItemContent
) -> some ToolbarContent {
    if hidesSharedBackground(item) {
        ToolbarItem(placement: placement) {
            content(item)
        }
        .sharedBackgroundVisibility(.hidden)
    } else {
        ToolbarItem(placement: placement) {
            content(item)
        }
    }
}

@ToolbarContentBuilder
public func plainToolbarItems<Item, ItemContent: View>(
    _ items: [Item],
    placement: ToolbarItemPlacement,
    @ViewBuilder content: (Item) -> ItemContent
) -> some ToolbarContent {
    if !items.isEmpty {
        ToolbarItem(placement: placement) { content(items[0]) }
    }
    if items.count >= 2 {
        ToolbarItem(placement: placement) { content(items[1]) }
    }
    // Limit to at most 3; there isn’t enough space for more.
    if items.count >= 3 {
        ToolbarItem(placement: placement) { content(items[2]) }
    }
    if items.count > 3 {
        let _ = assertionFailure("There are too many toolbar buttons")
        ToolbarItem(placement: placement) { EmptyView() }
    }
}
#endif
