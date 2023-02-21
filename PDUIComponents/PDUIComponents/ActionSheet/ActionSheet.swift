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
import UIKit
import ProtonCore_UIFoundations

extension View {
    public func actionSheet(isVisible: Binding<Bool>, model: ActionSheetModel) -> some View {
        ModifiedContent(content: self, modifier: ModalContainerModifierBool(isVisible: isVisible, model: model))
    }

    public func actionSheet<Item: Identifiable>(item: Binding<Item?>, model: @escaping (Item) -> ActionSheetModel) -> some View {
        ModifiedContent(content: self, modifier: ModalContainerModifier(item: item, model: model))
    }
}

private struct ModalContainerModifierBool: ViewModifier {
    var isVisible: Binding<Bool>
    let model: ActionSheetModel

    func body(content: Content) -> some View {
        content
        .background( ZStack {
            if isVisible.wrappedValue {
                ActionSheetContainter(isVisible: isVisible, model: model)
            }
        })
    }
}

private struct ModalContainerModifier<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let model: (Item) -> ActionSheetModel

    func body(content: Content) -> some View {
        content
        .background( ZStack {
            if item != nil {
                let isVisible = Binding(get: { item != nil }, set: { item = $0 ? item : .none })
                ActionSheetContainter(isVisible: isVisible, model: model(item!))
            }
        })
    }
}

struct ActionSheetContainter: UIViewControllerRepresentable {
    typealias UIViewControllerType = Injector
    var isVisible: Binding<Bool>
    let model: ActionSheetModel

    func makeUIViewController(context: Context) -> Injector {
        let proxyController = Injector()
        proxyController.overlay = UIViewController()
        proxyController.model = model
        proxyController.delegate = context.coordinator
        return proxyController
    }

    func updateUIViewController(_ uiViewController: Injector, context: Context) {
        if isVisible.wrappedValue {
            uiViewController.update(with: model)
        } else {
            Self.dismantleUIViewController(uiViewController, coordinator: context.coordinator)
        }
    }

    static func dismantleUIViewController(_ uiViewController: Injector, coordinator: Coordinator) {
        uiViewController.overlay?.dismiss(animated: false, completion: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(actionContainer: self)
    }

    class Coordinator: NSObject, PMActionSheetEventsListener {
        let actionContainer: ActionSheetContainter

        init(actionContainer: ActionSheetContainter) {
            self.actionContainer = actionContainer
        }

        func willPresent() {}

        func willDismiss() {
            actionContainer.isVisible.wrappedValue = false
        }

        func didDismiss() {}
    }

    class Injector: UIViewController {
        weak var delegate: PMActionSheetEventsListener?
        var overlay: UIViewController?
        var model: ActionSheetModel?
        var sheet: PMActionSheet?

        override func viewDidLoad() {
            super.viewDidLoad()
            overlay?.modalPresentationStyle = .overFullScreen
            overlay?.view.backgroundColor = .clear
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let model = model,
                  let child = overlay else { return }
            present(child, animated: false) { [weak self] in
                let headerView = PMActionSheetHeaderModel.makeView(from: model.header)
                let sheet = PMActionSheet(headerView: headerView, itemGroups: model.items)
                sheet.eventsListener = self?.delegate
                sheet.presentAt(child, hasTopConstant: false, animated: true)
                self?.sheet = sheet
            }
        }

        func update(with model: ActionSheetModel) {
            guard let overlay = overlay,
                  let oldSheet = sheet else { return }

            guard self.model != model else { return }
            self.model = model

            oldSheet.dismiss(animated: false)
            let headerView = PMActionSheetHeaderModel.makeView(from: model.header)
            let newSheet = PMActionSheet(headerView: headerView, itemGroups: model.items)
            newSheet.eventsListener = delegate
            sheet = newSheet
            newSheet.presentAt(overlay, hasTopConstant: false, animated: false)
        }
    }
}

public struct ActionSheetModel {
    public init(header: PMActionSheetHeaderModel?, items: [PMActionSheetItemGroup]) {
        self.header = header
        self.items = items
    }
    
    let header: PMActionSheetHeaderModel?
    let items: [PMActionSheetItemGroup]
}

extension ActionSheetModel: Equatable {
    public static func ==(lhs: ActionSheetModel, rhs: ActionSheetModel) -> Bool {
        return lhs.header == rhs.header && lhs.items == rhs.items
    }
}

extension PMActionSheetHeaderModel: Equatable {
    public static func ==(lhs: PMActionSheetHeaderModel, rhs: PMActionSheetHeaderModel) -> Bool {
        return lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }
}

extension PMActionSheetItemGroup: Equatable {
    public static func ==(lhs: PMActionSheetItemGroup, rhs: PMActionSheetItemGroup) -> Bool {
        guard lhs.items.count == rhs.items.count else { return false }
        let matches = [lhs.title == rhs.title, lhs.style == rhs.style] + zip(lhs.items, rhs.items).map { $0.title == $1.title }
        return !matches.contains(false)
    }
}
