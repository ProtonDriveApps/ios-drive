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

public enum FileUploaderError: LocalizedError {
    case noCredentialFound
    case insuficientSpace
    case verificationError(Error)
}

public extension FileUploaderError {
    var errorDescription: String? {
        switch self {
        case .noCredentialFound: 
            return "We can't retrieve your credentials to process upload"
        case .insuficientSpace:
            return "You do not have enough storage space to upload this file"
        case .verificationError(let error):
            return "Failed to verify upload: \(error.localizedDescription)"
        }
    }
}
