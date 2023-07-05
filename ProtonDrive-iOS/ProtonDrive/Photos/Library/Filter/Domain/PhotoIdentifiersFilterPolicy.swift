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
import PDCore

struct PhotoIdentifiersFilterResult {
    let validIdentifiers: [PhotoIdentifier]
    let invalidIdentifiersCount: Int
}

protocol PhotoIdentifiersFilterPolicyProtocol {
    func filter(identifiers: [PhotoIdentifier], metadata: [PhotoMetadata.iOSMeta]) -> PhotoIdentifiersFilterResult
}

final class PhotoIdentifiersFilterPolicy: PhotoIdentifiersFilterPolicyProtocol {
    func filter(identifiers: [PhotoIdentifier], metadata: [PhotoMetadata.iOSMeta]) -> PhotoIdentifiersFilterResult {
        var validIdentifiers = [PhotoIdentifier]()
        var invalidIdentifiers = [PhotoIdentifier]()
        identifiers.forEach { identifier in
            if !metadata.contains(where: { isEqual(identifier: identifier, metadata: $0) }) {
                validIdentifiers.append(identifier)
            } else {
                invalidIdentifiers.append(identifier)
            }
        }
        return PhotoIdentifiersFilterResult(validIdentifiers: validIdentifiers, invalidIdentifiersCount: invalidIdentifiers.count)
    }

    private func isEqual(identifier: PhotoIdentifier, metadata: PhotoMetadata.iOSMeta) -> Bool {
        return identifier.cloudIdentifier == metadata.cloudIdentifier && isEqualDate(identifier: identifier, metadata: metadata)
    }

    /// Due to Core data transformation between Date and String we need to approximate the difference.
    private func isEqualDate(identifier: PhotoIdentifier, metadata: PhotoMetadata.iOSMeta) -> Bool {
        if let identifierDate = identifier.modifiedDate, let metadataDate = metadata.modifiedDate {
            return abs(identifierDate.timeIntervalSince1970 - metadataDate.timeIntervalSince1970) < 1
        } else {
            return false
        }
    }
}
