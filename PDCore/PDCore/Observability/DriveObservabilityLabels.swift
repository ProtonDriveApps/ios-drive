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

// Definitions of common labels that are used by multiple drive observability metrics.
// Note that the keys of each enum must exactly match the json schemas.

public enum DriveObservabilityStatus: String, Encodable, Equatable {
    case success
    case failure
}

public enum DriveObservabilityRetry: String, Encodable, Equatable {
    case `true`
    case `false`
}

public enum DriveObservabilityInitiator: String, Encodable, Equatable {
    case background
    case explicit
}
