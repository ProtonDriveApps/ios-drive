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

import ProtonCoreUIFoundations
import PDCore
import PDUIComponents

protocol NodeRowActionMenuViewModelTrashAlertPresenting {
    var nodes: [Node] { get }
    var model: NodeEditionViewModel { get }
}

extension NodeRowActionMenuViewModelTrashAlertPresenting {
    func makeTrashAlert(environment: TrashAlertEnvironment) -> DialogSheetModel {
        let vm = TrashAlertViewModel(nodes: nodes, model: model)
        return DialogSheetModel(
            title: vm.trashText.title,
            buttons: [
                DialogButton(title: vm.trashText.button, role: .destructive, action: {
                    vm.trash(completion: { result in
                        switch result {
                        case .success:
                            environment.onDismiss()
                            environment.cancelSelection?()
                            environment.popScreenIfNeeded()
                        case .failure(let error):
                            environment.onDismiss()
                            vm.model.sendError(error)
                        }
                    })
                })
            ])
    }

}
