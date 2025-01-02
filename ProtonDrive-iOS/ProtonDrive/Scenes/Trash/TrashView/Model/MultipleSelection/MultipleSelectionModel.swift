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

import Foundation

final class MultipleSelectionModel<Identifier: Hashable> {
    
    enum SelectedItem: Equatable {
        case all
        case item(id: Identifier)
    }

    private(set) var selectable: Set<Identifier> {
        didSet { onEmptySelectable?(selectable.isEmpty) }
    }
    private(set) var selected = Set<Identifier>()
    var onEmptySelectable: ((Bool) -> Void)?

    init(selectable: Set<Identifier>) {
        self.selectable = selectable
    }

    func updateSelection(with selection: SelectedItem) {
        switch selection {
        case .all:
            if selected.count != selectable.count   {
                selected = selectable
            } else {
                selected.removeAll()
            }
        case .item(id: let id):
            if selected.contains(id)  {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
        }
    }

    func updateSelectable(_ new: Set<Identifier>) {
        selectable = new
        selected = selected.intersection(new)
    }

    func clearSelected() {
        selected.removeAll()
        hideTabBar(false)
    }

    func hideTabBar(_ hidden: Bool) {
        NotificationCenter.default.post(name: FinderNotifications.tabBar.name, object: hidden)
    }
}
