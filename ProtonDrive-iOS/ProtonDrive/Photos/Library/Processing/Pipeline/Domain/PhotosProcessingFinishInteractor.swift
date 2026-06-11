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
import PDCore
import PDCoreIOS

final class PhotosProcessingFinishInteractor: AsynchronousExecution {
    private let context: PhotosProcessingContext
    private let progressRepository: PhotoLibraryLoadProgressRepository
    private let failedIdentifiersResource: DeletedPhotosIdentifierStoreResource

    init(context: PhotosProcessingContext, progressRepository: PhotoLibraryLoadProgressRepository, failedIdentifiersResource: DeletedPhotosIdentifierStoreResource) {
        self.context = context
        self.progressRepository = progressRepository
        self.failedIdentifiersResource = failedIdentifiersResource
    }

    func execute() async {
        Log.info("5️⃣ executing", domain: .photosProcessing)
        context.failedIdentifiersAndError.forEach { failedIdentifiersResource.increment(cloudIdentifier: $0.key.cloudIdentifier, error: $0.value) }
        progressRepository.discard(context.invalidIdentifiers.count + context.missingIdentifiers.count)
        progressRepository.add(context.importedCompoundsDeltaCount)
        progressRepository.finish(context.importedCompoundsCount + context.failedIdentifiersAndError.count)
        Log.info("5️⃣ finished importing count: \(context.importedCompoundsCount), compoundsDelta: \(context.importedCompoundsDeltaCount)", domain: .photosProcessing)
    }
}
