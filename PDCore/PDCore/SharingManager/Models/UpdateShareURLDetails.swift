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

public struct UpdateShareURLDetails: Equatable {
    public let password: Password
    public let duration: Duration
    public let permission: Permissions

    public init(
        password: UpdateShareURLDetails.Password,
        duration: UpdateShareURLDetails.Duration,
        permission: Permissions
    ) {
        self.password = password
        self.duration = duration
        self.permission = permission
    }

    public enum Password: Equatable {
        case unchanged
        case updated(String)
    }

    public enum Duration: Equatable {
        case unchanged
        case nonExpiring
        case expiring(TimeInterval)
    }
    
    public enum Permissions: Equatable {
        case unchanged
        case read
        case readAndWrite
    }
}
