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

import UIKit
import SwiftUI
import PDCore
import ProtonCoreUIFoundations

final class EditNodeCoordinator: SwiftUICoordinator {
    typealias Context = (tower: Tower, parent: Folder, intention: Intention)
    func go(to destination: Never) -> Never { }
    
    enum Intention {
        case create, rename(Node)
    }
    
    func start(_ context: Context) -> EditNodeUIKitView {
        let model = EditNodeModel(tower: context.tower, parent: context.parent)
        let validator = NameValidations.userSelectedName
        let nameAttributes = EditNodeViewController.nameAttributes
        let extAttributes = EditNodeViewController.nameAttributes
        
        switch context.intention {
        case .create:
            let vm = CreateFolderViewModel(folderCreator: model, validator: validator)
            let nfvm = FormattingFolderViewModel(initialName: nil, attributes: nameAttributes)
            return EditNodeUIKitView(vm: vm, nfvm: nfvm)
        case .rename(let node):
            let node = NameEditingNode(node: node)
            let vm = EditNodeNameViewModel(node: node, nameEditor: model, validator: validator)
            let nfvm: NameFormattingViewModel = node.type == .file ?
                FormattingFileViewModel(initialName: node.fullName,
                                        nameAttributes: nameAttributes,
                                        extensionAttributes: extAttributes)
                :
                FormattingFolderViewModel(initialName: node.fullName,
                                          attributes: [.foregroundColor: UIColor(ColorProvider.TextNorm)])
            return EditNodeUIKitView(vm: vm, nfvm: nfvm)
        }
    }
}
