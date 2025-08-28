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

public protocol FlatNavigationBarDelegate: AnyObject {
    func numberOfControllers(_ count: Int, _ root: RootViewModel)
}

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

public extension View {
    func flatNavigationBar<L, T>(
        _ title: String,
        isRoot: Bool,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        delegate: FlatNavigationBarDelegate? = nil,
        leading: L?,
        trailing: T?
    ) -> some View where L: View, T: View {

        let modifier = NavigationBarModifier(title: title, isRoot: isRoot, displayMode: displayMode, coordinator: delegate, leading: leading, trailing: trailing)
        return ModifiedContent(content: self, modifier: modifier)
    }
}

struct NavigationBarModifier<L, T>: ViewModifier where L: View, T: View {
//    @EnvironmentObject var root: RootViewModel
    @Environment(\.colorScheme) var colorScheme

    let title: String
    let isRoot: Bool
    var displayMode: NavigationBarItem.TitleDisplayMode
    var coordinator: FlatNavigationBarDelegate?
    let leading: L?
    let trailing: T?

    public func body(content: Content) -> some View {
        content
            .navigationBarTitle(Text(""), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leading
                }

                let placement: ToolbarItemPlacement = isRoot ? .topBarLeading : .principal
                ToolbarItem(placement: placement) {
                    Text(title)
                        .font(isRoot ? .system(.title2) : .system(.body))
                        .fontWeight(isRoot ? .bold : .semibold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    trailing
                }
            }
            .background(
                NavigationControllerAccessor(willAppearCallback: { navController in
                }, didAppearCallback: { navController in
                    UINavigationBar.setupFlatNavigationBarSystemWide()
                })
                .id(colorScheme) // will trick SwiftUI into reloading the view when ColorScheme cnahges
            )
    }
}
#endif
