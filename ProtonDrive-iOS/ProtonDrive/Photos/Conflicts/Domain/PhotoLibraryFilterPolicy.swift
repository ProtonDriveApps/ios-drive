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

import PDCore

/// The idea is to resolve duplicities as soon as possible.
/// Some duplicities are possible to be resolved with identifiers, some only after we have the contentHash.
protocol PhotoLibraryFilterPolicy {
    func filterIdentifiers(_ identifiers: PhotoIdentifiers) -> PhotoIdentifiers
    func filterCompounds(_ compounds: [PhotoAssetCompound]) -> [PhotoAssetCompound]
}

// TODO: next MR: add real implementation (exclude db entries)
final class DummyPhotoLibraryFilterPolicy: PhotoLibraryFilterPolicy {
    func filterIdentifiers(_ identifiers: PhotoIdentifiers) -> PhotoIdentifiers {
        return identifiers
    }

    func filterCompounds(_ compounds: [PhotoAssetCompound]) -> [PhotoAssetCompound] {
        return compounds
    }
}