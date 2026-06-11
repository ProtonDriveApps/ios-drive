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

actor CancellationTokenStore {
    var tokens: [AnyVolumeIdentifier: UUID] = [:]

    func token(for id: AnyVolumeIdentifier) -> UUID? {
        tokens[id]
    }

    func setToken(_ token: UUID, for id: AnyVolumeIdentifier) {
        tokens[id] = token
    }

    @discardableResult
    func remove(for id: AnyVolumeIdentifier) -> UUID? {
        let token = tokens[id]
        tokens[id] = nil
        return token
    }

    func removeAll() -> [AnyVolumeIdentifier: UUID] {
        let copied = tokens
        tokens = [:]
        return copied
    }
}
