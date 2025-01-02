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

// MARK: - EncryptingParent

/// DTO that represents a Folder and gives the minimum data required for creating new File within said Folder.
public struct EncryptingFolder {
    public let id: String
    public let shareID: String
    public let volumeID: String
    public let hashKey: HashKey
    public let nodeKey: ArmoredKey
}

extension Folder {
    public func encrypting() throws -> EncryptingFolder {
        let nodeHashKey = try decryptNodeHashKey()

        return EncryptingFolder(
            id: id,
            shareID: shareId,
            volumeID: volumeID,
            hashKey: nodeHashKey,
            nodeKey: nodeKey
        )
    }
}
