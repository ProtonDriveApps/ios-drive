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

import PDCore
import ProtonCoreUIFoundations
import UIKit
import PDUIComponents

extension NodeRowActionMenuViewModel {
    typealias MoreSectionItem = MoreSectionViewModel.MoreSectionItem
    
    func moreSection(environment: Environment) -> ContextMenuItemGroup {
        let moreViewModel = MoreSectionViewModel(file: node as! File)
        let items = moreViewModel.items.map { item in
            singleMoreRows(for: item, environment: environment)
        }
        return ContextMenuItemGroup(id: "moreSection", items: items)
    }
    
    private func singleMoreRows(for type: MoreSectionItem, environment: Environment) -> ContextMenuItem {
        switch type {
        case .shareIn: return shareIn(type, environment: environment)
        }
    }
    
    private func shareIn(_ type: MoreSectionItem, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.shareIn(file: node as! File)
        })
    }
}
