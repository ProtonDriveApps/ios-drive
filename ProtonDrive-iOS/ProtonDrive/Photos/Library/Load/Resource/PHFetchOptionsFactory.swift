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

import Combine
import Photos

final class PHFetchOptionsFactory {
    private let supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never>
    private let notOlderThan: CurrentValueSubject<Date, Never>

    init(supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never>, notOlderThan: CurrentValueSubject<Date, Never>) {
        self.supportedMediaTypes = supportedMediaTypes
        self.notOlderThan = notOlderThan
    }

    func makeOptions() -> PHFetchOptions {
        let options = PHFetchOptions.defaultPhotosOptions()
        options.predicate = NSPredicate(format: "mediaType IN %@ AND creationDate >= %@", supportedMediaTypes.value.map(\.asAssetType.rawValue), notOlderThan.value as NSDate)
        return options
    }
}

// FIXME: Use and inject `PHFetchOptionsFactory` instead of this.
// Move implementation below to `PHFetchOptionsFactory` after.
extension PHFetchOptions {
    static func defaultPhotosOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced]
        return options
    }
}
