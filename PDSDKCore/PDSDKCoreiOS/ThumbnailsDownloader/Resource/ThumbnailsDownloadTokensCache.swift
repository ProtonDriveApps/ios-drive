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

actor ThumbnailsDownloadTokensCache {
    private var tokens: [Key: UUID] = [:]

    func token(for identifier: AnyVolumeIdentifier, type: ThumbnailType) -> UUID? {
        let key = makeKey(for: identifier, type: type)
        return tokens[key]
    }

    func setToken(_ token: UUID, for identifier: AnyVolumeIdentifier, type: ThumbnailType) {
        let key = makeKey(for: identifier, type: type)
        tokens[key] = token
    }

    @discardableResult
    func remove(for identifier: AnyVolumeIdentifier, type: ThumbnailType) -> UUID? {
        let key = makeKey(for: identifier, type: type)
        let token = tokens[key]
        tokens[key] = nil
        return token
    }

    private func makeKey(for identifier: AnyVolumeIdentifier, type: ThumbnailType) -> Key {
        Key(identifier: identifier, type: type)
    }

    private struct Key: Hashable {
        let identifier: AnyVolumeIdentifier
        let type: ThumbnailType
    }
}
