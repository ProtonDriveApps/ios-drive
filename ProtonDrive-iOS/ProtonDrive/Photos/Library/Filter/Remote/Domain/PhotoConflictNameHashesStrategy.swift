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

import PDClient

protocol PhotoConflictNameHashesStrategy {
    func validate(item: PhotosFilterItem, remoteItems: [PhotoRemoteDuplicateCheckItem]) throws
}

enum PhotoConflictNameHashesStrategyError: Error {
    case conflictingName
}

final class LocalPhotoConflictNameHashesStrategy: PhotoConflictNameHashesStrategy {
    func validate(item: PhotosFilterItem, remoteItems: [PhotoRemoteDuplicateCheckItem]) throws {
        let localHashes = item.allIdentifiers.map(\.nameHash)
        let remoteHashes = remoteItems.map(\.hash)
        let isDisjoint = Set(remoteHashes).isDisjoint(with: localHashes)
        guard isDisjoint else {
            throw PhotoConflictNameHashesStrategyError.conflictingName
        }
    }
}
