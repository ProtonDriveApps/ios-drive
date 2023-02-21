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

import ProtonCore_UIFoundations
import UIKit
import PDUIComponents

extension NodeRowActionMenuViewModel {
    typealias EditSectionItem = EditSectionViewModel.EditSectionItem
    typealias Environment = EditSectionEnvironment
    typealias Dismiss = () -> Void
    
    func makeActionMenu(environment: Environment) -> ContextMenuModel {
        var items: [ContextMenuItemGroup] = []
        switch section {
        case .file:
            items.append(editSection(environment: environment))
            items.append(moreSection(environment: environment))
        case .folder:
            if isNavigationMenu {
                items.append(uploadSection(environment: environment))
            }
            items.append(editSection(environment: environment))
        }
        return ContextMenuModel(items: items)
    }
}

extension NodeRowActionMenuViewModel {
    func editSection(environment: Environment) -> ContextMenuItemGroup {
        let editViewModel = EditSectionViewModel(node: node, model: model)
        let items = editViewModel.items.map { item in
            singleEditRows(for: item, vm: editViewModel, environment: environment)
        }
        return ContextMenuItemGroup(items: items)
    }
    
    private func singleEditRows(for type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        switch type {
        case .share: return share(type, vm: vm, environment: environment)
        case .shareLink: return shareLink(type, vm: vm, environment: environment)
        case .download: return download(type, vm: vm, environment: environment)
        case .rename: return rename(type, vm: vm, environment: environment)
        case .move: return move(type, vm: vm, environment: environment)
        case .details: return details(type, vm: vm, environment: environment)
        case .remove: return remove(type, vm: vm, environment: environment)
        }
    }
    
    private func share(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: { environment.onDismiss() })
    }
    
    private func shareLink(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: { environment.shareLink(of: node) })
    }
    
    private func download(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: { environment.availableOffline(vm: vm) })
    }
    
    private func rename(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: { environment.rename(vm: vm) })
    }
    
    private func move(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: { environment.move(vm: vm) })
    }
    
    private func details(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: { environment.showDetails(vm: vm) })
    }
    
    private func remove(_ type: EditSectionItem, vm: EditSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, role: .destructive, handler: {
            environment.trashNode(of: self, isNavigationMenu: isNavigationMenu)
        })
    }
}
