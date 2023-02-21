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
import PDUIComponents

protocol HasMultipleSelection: AnyObject {
    var isUpdating: Bool { get set }
    var listState: ListState { get set }
    var selection: MultipleSelectionModel { get }
    func actionBarAction(_ tapped: ActionBarButtonViewModel?, sheet: Binding<FinderCoordinator.Destination?>, menuItem: Binding<FinderMenu?>)
}

extension HasMultipleSelection {
    func titleDuringSelection() -> String {
        "\(selection.selected.count) selected"
    }
    
    func applyAction(completion: () -> Void) {
        isUpdating = false
        selection.updateSelection(with: .all)
        completion()
    }
    
    func prepareSelectionModel() -> CellSelectionModel {
        let binding: Binding<Bool> = Binding(
            get: { [weak self] in self?.listState.isSelecting == true },
            set: { [weak self] in self?.listState = $0 ? .selecting : .active })
           
        return CellSelectionModel(state: binding, sm: self.selection)
    }
    
    func cancelSelection() {
        DispatchQueue.main.async {
            self.listState = .active
            self.selection.clearSelected()
        }
    }
    
}

extension HasMultipleSelection {
    func actionBarItems() -> [ActionBarButtonViewModel] {
        [.trashMultiple, .moveMultiple, .offlineAvailableMultiple]
    }
}
