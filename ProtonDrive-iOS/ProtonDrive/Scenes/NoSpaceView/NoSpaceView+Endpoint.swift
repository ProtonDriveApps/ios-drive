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

extension NoSpaceView {
    enum Storage {
        case local, cloud
    
        var title: String {
            switch self {
            case .local:
                return "Your device is packed."
            case .cloud:
                return "You reached the limit of your plan."
            }
        }
        
        var subtitle: String {
            switch self {
            case .local:
                return "There is not enough storage on your device to download all the files marked as offline available."
            case .cloud:
                return "Not enough storage space to upload. Please consider upgrading your account or contact our customer support."
            }
        }
    }
}
