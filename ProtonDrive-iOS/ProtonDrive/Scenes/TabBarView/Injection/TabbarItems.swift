// Copyright (c) 2024 Proton AG
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
import UIKit
import ProtonCoreUIFoundations

enum TabBarItem: CaseIterable {
    case files, photos, shared
    
    var icon: UIImage {
        switch self {
        case .files:
            return IconProvider.folder
        case .photos:
            return IconProvider.image
        case .shared:
            return IconProvider.link
        }
    }
    
    var title: String {
        switch self {
        case .files:
            return "Files"
        case .photos:
            return "Photos"
        case .shared:
            return "Shared"
        }
    }
    
    var tag: Int {
        switch self {
        case .files:
            return 0
        case .photos:
            return 1
        case .shared:
            return 2
        }
    }
    
    var accessibilityIdentifier: String {
        switch self {
        case .files:
            return "Files"
        case .photos:
            return "Photos"
        case .shared:
            return "Shared"
        }
    }
    
    init?(tag: Int) {
        switch tag {
        case 0: self = .files
        case 1: self = .photos
        case 2: self = .shared
        default: return nil
        }
    }
}
