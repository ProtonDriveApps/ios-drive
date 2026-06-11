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
import PDCore
import Photos

public protocol PhotoIdentifierStore {
    func store(allIdentifiers: PhotoIdentifiers)
    func update(changedIdentifiers: PhotoIdentifiers)
}

public protocol PhotoIdentifierInquirer {
    func localIdentifier(forCloudIdentifier cloudIdentifier: String) -> String?
}

public final class PhotoIdentifiersRepository {
    /// [Cloud identifier: local identifier]
    @ThreadSafe private var identifiers: [String: String] = [:]

    public init() { }
}

extension PhotoIdentifiersRepository: PhotoIdentifierStore {
    public func store(allIdentifiers: PhotoIdentifiers) {
        var tmp: [String: String] = [:]
        for identifier in allIdentifiers {
            tmp[identifier.cloudIdentifier] = identifier.localIdentifier
        }
        identifiers = tmp
    }

    public func update(changedIdentifiers: PhotoIdentifiers) {
        for identifier in changedIdentifiers {
            identifiers[identifier.cloudIdentifier] = identifier.localIdentifier
        }
    }
}

extension PhotoIdentifiersRepository: PhotoIdentifierInquirer {
    public func localIdentifier(forCloudIdentifier cloudIdentifier: String) -> String? {
        identifiers[cloudIdentifier]
    }
}
