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

import Combine
import Photos
import PDCoreIOS

public final class PHFetchOptionsFactory {
    private let supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never>
    private let notOlderThan: CurrentValueSubject<Date, Never>

    public init(
        supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never>,
        notOlderThan: CurrentValueSubject<Date, Never>
    ) {
        self.supportedMediaTypes = supportedMediaTypes
        self.notOlderThan = notOlderThan
    }

    public func makeOptions() -> PHFetchOptions {
        let mediaPredicate = NSPredicate(format: "mediaType IN %@", supportedMediaTypes.value.map(\.asAssetType.rawValue))
        let notOrderPredicate = NSPredicate(format: "creationDate >= %@", notOlderThan.value as NSDate)
        let options = PHFetchOptions.defaultPhotosOptions()
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [mediaPredicate, notOrderPredicate])
        return options
    }
}
