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

struct PhotosListConfiguration: Equatable {
    let volumeId: String
    let albumId: String?
    /// Photos stream is split into sections while album photos are a single one.
    /// Having this in configuration speeds up mapping to domain/presentation objects
    let isSingleSection: Bool
    let shouldLoadAllAtOnce: Bool

    init(volumeId: String, albumId: String?, shouldLoadAllAtOnce: Bool = false) {
        self.volumeId = volumeId
        self.albumId = albumId
        isSingleSection = albumId != nil
        self.shouldLoadAllAtOnce = shouldLoadAllAtOnce
    }
}
