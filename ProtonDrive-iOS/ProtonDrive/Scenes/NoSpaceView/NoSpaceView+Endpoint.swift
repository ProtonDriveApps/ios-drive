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
import PDLocalization

extension NoSpaceView {
    enum Storage {
        case local, cloud
    
        var title: String {
            switch self {
            case .local:
                return Localization.no_space_title_device_is_packed
            case .cloud:
                return Localization.no_space_title_limit_of_plan
            }
        }
        
        var subtitle: String {
            switch self {
            case .local:
                return Localization.no_space_subtitle_device_full
            case .cloud:
                return Localization.no_space_subtitle_cloud_full
            }
        }
    }
}
