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
import PDCore

final class CellSelectionModel {
    let selecting: Binding<Bool>
    let sm: MultipleSelectionModel<NodeIdentifier>

    init(state: Binding<Bool>, sm: MultipleSelectionModel<NodeIdentifier>) {
        self.selecting = state
        self.sm = sm
    }

    func onLongPress() {
        let impactMed = UIImpactFeedbackGenerator(style: .heavy)
            impactMed.impactOccurred()
        selecting.wrappedValue.toggle()
        sm.clearSelected()
        sm.hideTabBar(selecting.wrappedValue)
    }

    func onTap(id: NodeIdentifier) {
        sm.updateSelection(with: .item(id: id))
        selecting.wrappedValue = true
    }

    var isMultipleSelectionEnabled: Bool {
        selecting.wrappedValue
    }

    func isSelected(id: NodeIdentifier) -> Bool {
        sm.selected.contains(id)
    }
}
