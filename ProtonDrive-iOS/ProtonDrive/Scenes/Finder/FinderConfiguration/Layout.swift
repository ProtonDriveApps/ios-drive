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

enum Layout {
    case list
    case grid

    var next: Layout {
        switch self {
        case .list:
            return .grid
        case .grid:
            return .list
        }
    }

    init(preference: LayoutPreference) {
        switch preference {
        case .grid:
            self = .grid
        default:
            self = .list
        }
    }

    var asPreference: LayoutPreference {
        switch self {
        case .list:
            return .list
        case .grid:
            return .grid
        }
    }
}

extension Layout {
    var finderLayout: [GridItem] {
        switch self {
        case .grid:
            return [GridItem(.adaptive(minimum: GridCellConstants.grid + 2))]
        case .list:
            return [GridItem(.flexible())]
        }
    }

    var spacing: CGFloat {
        switch self {
        case .grid:
            return 8
        case .list:
            return 0
        }
    }
}
