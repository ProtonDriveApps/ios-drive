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

#if os(iOS)
import SwiftUI
import ProtonCoreUIFoundations
import UIKit

extension View {

    @ViewBuilder
    public func dialogSheet<Item: Identifiable>(item: Binding<Item?>, model: DialogSheetModel) -> some View {
        self.modifier(
            DialogContainerModifier(item: item, model: model)
        )
    }

}

private struct DialogContainerModifier<Item: Identifiable>: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var currentWidth: CGFloat = 0

    @Binding var item: Item?
    let model: DialogSheetModel

    var isVisible: Binding<Bool> {
        Binding(get: { item != nil }, set: { item = $0 ? item : .none })
    }

    func body(content: Content) -> some View {
        Group {
            if currentWidth == 0 {
                content
            } else if useCompactLayout() {
                confirmationDialogLayout(content: content)
            } else {
                alertLayout(content: content)
            }
        }
        .modifier(
            GetWidthModifier(
                width: .init(
                    get: { currentWidth },
                    set: { newValue in
                        // Somehow the width becomes 0 from time to time after splitting view
                        if newValue == 0 { return }
                        currentWidth = newValue
                    }
                )
            )
        )
    }

    private func useCompactLayout() -> Bool {
        // horizontalSizeClass on iPhone always compact
        guard UIDevice.current.isIpad else { return true }
        if horizontalSizeClass == .regular { return false }

        // At least on iPad Pro(12.9), iOS 18.0+
        // The horizontalSizeClass reports is incorrect, report compact rather than regular
        let screenWidth = UIScreen.main.bounds.width
        return currentWidth < screenWidth
    }

    @ViewBuilder
    private func confirmationDialogLayout(content: Content) -> some View {
        content
            .confirmationDialog("", isPresented: isVisible) {
                ForEach(model.buttons) { button in
                    Button(
                        button.title,
                        role: button.role == .destructive ? .destructive : nil,
                        action: button.action
                    )
                }
            } message: {
                Text(model.title)
            }
    }

    @ViewBuilder
    private func alertLayout(content: Content) -> some View {
        content
            .alert("", isPresented: isVisible) {
                ForEach(model.buttons) { button in
                    Button(
                        button.title,
                        role: button.role == .destructive ? .destructive : nil,
                        action: button.action
                    )
                }
            } message: {
                Text(model.title)
            }
    }
}

public struct DialogSheetModel: Identifiable {
    public let id = UUID()

    let title: String
    let buttons: [DialogButton]

    public init(title: String, buttons: [DialogButton]) {
        self.title = title
        self.buttons = buttons
    }

    public static let placeholder = DialogSheetModel(title: "", buttons: [])

}

public struct DialogButton: Identifiable {

    public let id = UUID()
    public let title: String
    public let role: Role
    public let action: (() -> Void)

    public enum Role {
        case `default`
        case destructive
    }

    public init(title: String, role: Role, action: @escaping (() -> Void) = {}) {
        self.title = title
        self.role = role
        self.action = action
    }

}

extension View {
    @ViewBuilder
    public func dialogConfirmationSheet(model: Binding<DialogSheetModel?>) -> some View {
        self.modifier(DialogSheetContainerModifier(item: model))
    }
}

private struct DialogSheetContainerModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var currentWidth: CGFloat = 0

    @Binding var item: DialogSheetModel?

    var isVisible: Binding<Bool> {
        Binding(
            get: {
                item != nil
            },
            set: { newValue in
                if !newValue {
                    item = nil
                }
            }
        )
    }

    func body(content: Content) -> some View {
        Group {
            if currentWidth == 0 {
                content
            } else if useCompactLayout() {
                confirmationDialogLayout(content: content)
            } else {
                alertLayout(content: content)
            }
        }
        .modifier(
            GetWidthModifier(
                width: .init(
                    get: { currentWidth },
                    set: { newValue in
                        // Somehow the width becomes 0 from time to time after splitting view
                        if newValue == 0 { return }
                        currentWidth = newValue
                    }
                )
            )
        )
    }

    private func useCompactLayout() -> Bool {
        // horizontalSizeClass on iPhone always compact
        guard UIDevice.current.isIpad else { return true }
        if horizontalSizeClass == .regular { return false }

        // At least on iPad Pro(12.9), iOS 18.0+
        // The horizontalSizeClass reports is incorrect, report compact rather than regular
        let screenWidth = UIScreen.main.bounds.width
        return currentWidth < screenWidth
    }

    @ViewBuilder
    private func confirmationDialogLayout(content: Content) -> some View {
        content
            .confirmationDialog("", isPresented: isVisible) {
                if let item {
                    ForEach(item.buttons) { button in
                        Button(
                            button.title,
                            role: button.role == .destructive ? .destructive : nil,
                            action: button.action
                        )
                    }
                }
            } message: {
                if let item {
                    Text(item.title)
                }
            }
    }

    @ViewBuilder
    private func alertLayout(content: Content) -> some View {
        content
            .alert("", isPresented: isVisible) {
                if let item {
                    ForEach(item.buttons) { button in
                        Button(
                            button.title,
                            role: button.role == .destructive ? .destructive : nil,
                            action: button.action
                        )
                    }
                }
            } message: {
                if let item {
                    Text(item.title)
                }
            }
    }
}
#endif
