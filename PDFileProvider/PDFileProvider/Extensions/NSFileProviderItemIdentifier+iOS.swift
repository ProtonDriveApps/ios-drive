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

import FileProvider

// FileProvider implementations on different platforms have some misalignments
// Here we'll add some mocks to simplify code of PDFileProvider framework

#if os(iOS)

public struct NSFileProviderRequest {}

public struct NSFileProviderItemVersion {
    init() { }
    init(contentVersion: Data, metadataVersion: Data) { }
}

public struct NSFileProviderItemFields: OptionSet {
    public let rawValue: Int
    
    public static let parentItemIdentifier = NSFileProviderItemFields(rawValue: 1 << 0)
    public static let filename = NSFileProviderItemFields(rawValue: 1 << 1)
    public static let contents = NSFileProviderItemFields(rawValue: 1 << 2)
    public static let creationDate = NSFileProviderItemFields(rawValue: 1 << 3)
    public static let extendedAttributes = NSFileProviderItemFields(rawValue: 1 << 4)
    public static let contentModificationDate = NSFileProviderItemFields(rawValue: 1 << 5)
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct NSFileProviderDeleteItemOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct NSFileProviderModifyItemOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct NSFileProviderCreateItemOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension Errors: Equatable {
    public static func == (lhs: Errors, rhs: Errors) -> Bool {
        switch (lhs, rhs) {
        case (deletionRejected(let lhsItem), deletionRejected(let rhsItem)):
            return lhsItem.itemIdentifier == rhsItem.itemIdentifier
        case (.noMainShare, .noMainShare): fallthrough
        case (.nodeIdentifierNotFound, .nodeIdentifierNotFound): fallthrough
        case (.nodeNotFound, .nodeNotFound): fallthrough
        case (.rootNotFound, .rootNotFound): fallthrough
        case (.revisionNotFound, .revisionNotFound): fallthrough
        case (.parentNotFound, .parentNotFound): fallthrough
        case (.urlForUploadIsNil, .urlForUploadIsNil): fallthrough
        case (.urlForUploadHasNoSize, .urlForUploadHasNoSize): fallthrough
        case (.urlForUploadFailedCopying, .urlForUploadFailedCopying): fallthrough
        case (.noAddressInTower, .noAddressInTower): fallthrough
        case (.couldNotProduceSyncAnchor, .couldNotProduceSyncAnchor): fallthrough
        case (.requestedItemForWorkingSet, .requestedItemForWorkingSet): fallthrough
        case (.requestedItemForTrash, .requestedItemForTrash): fallthrough
        case (.failedToCreateModel, .failedToCreateModel):
            return true
        default:
            return false
        }
    }
}

#endif
