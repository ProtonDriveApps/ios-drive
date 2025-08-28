// Copyright (c) 2025 Proton AG
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

public enum DriveObservabilityIntegrityEntity: String, Encodable, Equatable {
    case share
    case node
    case content
}

public enum DriveObservabilityIntegrityShareType: String, Encodable, Equatable {
    case main
    case device
    case photo
    case shared
    case shared_public
}

public enum DriveObservabilityIntegrityBeforeFebruary2025: String, Encodable, Equatable {
    case yes
    case no
    case unknown
}

public enum DriveObservabilityIntegrityRetryHelped: String, Encodable, Equatable {
    case yes
    case no
}

public enum DriveObservabilityIntegrityFileSize: String, Encodable, Equatable {
    case lessThen1KB = "2**10"
    case between1KBAnd1MB = "2**20"
    case between1MBAnd4MB = "2**22"
    case between4MBAnd33MB = "2**25"
    case between33MBAnd1GB = "2**30"
    case over1GB = "xxxxl"
}

public enum DriveObservabilityIntegrityPlan: String, Encodable, Equatable {
    case free
    case paid
    case anonymous
    case unknown
}
