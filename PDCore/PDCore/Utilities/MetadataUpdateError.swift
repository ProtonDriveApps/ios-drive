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

import Foundation

/// All the metadata update methods are expected to return this type of error
public enum MetadataUpdateError: LocalizedError {
    case noCachedResponse(missingResponse: String)
    case fieldMissing(missingField: String)
    case unexpectedFieldValue(field: String, value: String)
    case metadataUpdateFailed(inner: Swift.Error)

    public var errorDescription: String? {
        switch self {
        case .noCachedResponse(let missingResponse):
            return "MetadataUpdateError.noCachedResponse: \(missingResponse)"
        case .fieldMissing(let missingField):
            return "MetadataUpdateError.fieldMissing: \(missingField)"
        case let .unexpectedFieldValue(field, value):
            return "MetadataUpdateError.unexpectedFieldValue: \(field), \(value)"
        case .metadataUpdateFailed(let inner):
            return "MetadataUpdateError.metadataUpdateFailed: \(inner.localizedDescription)"
        }
    }
}
