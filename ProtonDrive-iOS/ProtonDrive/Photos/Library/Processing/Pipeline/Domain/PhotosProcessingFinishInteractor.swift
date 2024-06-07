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

final class PhotosProcessingFinishInteractor: AsynchronousExecution {
    private let context: PhotosProcessingContext
    private let progressRepository: PhotoLibraryLoadProgressRepository
    private let localStorageResource: LocalStorageResource
    private let failedIdentifiersResource: DeletedPhotosIdentifierStoreResource

    init(context: PhotosProcessingContext, progressRepository: PhotoLibraryLoadProgressRepository, localStorageResource: LocalStorageResource, failedIdentifiersResource: DeletedPhotosIdentifierStoreResource) {
        self.context = context
        self.progressRepository = progressRepository
        self.localStorageResource = localStorageResource
        self.failedIdentifiersResource = failedIdentifiersResource
    }

    func execute() async {
        Log.info("5️⃣ \(Self.self): executing", domain: .photosProcessing)
        context.failedIdentifiers.forEach { failedIdentifiersResource.increment(cloudIdenfier: $0.cloudIdentifier) }
        progressRepository.discard(context.invalidIdentifiers.count + context.missingIdentifiers.count)
        progressRepository.add(context.importedCompoundsDeltaCount)
        progressRepository.finish(context.importedCompoundsCount + context.failedIdentifiers.count)
        deleteInvalidAssets(context.invalidAssets)
        Log.info("5️⃣ \(Self.self): finished importing count: \(context.importedCompoundsCount), compoundsDelta: \(context.importedCompoundsDeltaCount)", domain: .photosProcessing)
    }

    private func deleteInvalidAssets(_ assets: [PhotoAsset]) {
        let urls = assets.map(\.url)
        urls.forEach {
            try? localStorageResource.delete(at: $0)
        }
    }
}
