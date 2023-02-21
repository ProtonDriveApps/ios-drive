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

import Combine
import Foundation

enum GridButtonState {
    case simple
    case menu(NodeCellButton)
    case selection(selected: Bool)
    case downloading(progress: String)
}

extension NodeCellConfiguration {
    var buttonState: GridButtonState {
        if isSelecting {
            return .selection(selected: isSelected)
        }

        if let vm = self as? NodeCellWithProgressConfiguration, isInProgress && progressDirection == .downstream {
            return .downloading(progress: vm.percentageDownloaded)
        }

        if let menu = buttons.first {
            return .menu(menu)
        } else {
            return .simple
        }
    }
}
