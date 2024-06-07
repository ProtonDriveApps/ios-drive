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

final class PhotosFilterSkippableInteractor: AsynchronousExecution {
    private let context: PhotosProcessingContext
    private let skippableCache: PhotosSkippableCache

    init(context: PhotosProcessingContext, skippableCache: PhotosSkippableCache) {
        self.context = context
        self.skippableCache = skippableCache
    }

    func execute() async {
        Log.info("0️⃣ \(Self.self): executing", domain: .photosProcessing)
        let identifiers = await filterSkippableOut(Array(context.initialIdentifiers))
        context.completeIdentifiersValidation(identifiers: identifiers)
    }
    
    func filterSkippableOut(_ identifiers: [PhotoIdentifier]) async -> [PhotoIdentifier] {
        identifiers.filter {
            !skippableCache.isSkippable($0)
        }
    }
}
