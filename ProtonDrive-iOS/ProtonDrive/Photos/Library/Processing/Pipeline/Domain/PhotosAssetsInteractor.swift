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

actor PhotosAssetsInteractor: AsynchronousExecution {
    private let context: PhotosProcessingContext
    private let resource: PhotoLibraryAssetsResource
    private let sizeResource: PhotoCompoundsSizeResource
    private let errorPolicy: PhotoAssetErrorPolicy
    private let skippableCache: PhotosSkippableCache
    private let sizeLimit: Int
    private let measurementRepository: DurationMeasurementRepository
    private var isCancelled = false

    init(context: PhotosProcessingContext, resource: PhotoLibraryAssetsResource, sizeResource: PhotoCompoundsSizeResource, errorPolicy: PhotoAssetErrorPolicy, skippableCache: PhotosSkippableCache, sizeLimit: Int, measurementRepository: DurationMeasurementRepository) {
        self.context = context
        self.resource = resource
        self.sizeResource = sizeResource
        self.errorPolicy = errorPolicy
        self.skippableCache = skippableCache
        self.sizeLimit = sizeLimit
        self.measurementRepository = measurementRepository
    }

    func execute() async {
        Log.info("2️⃣ \(Self.self): executing", domain: .photosProcessing)
        measurementRepository.start()
        for identifier in context.validIdentifiers {
            if isCancelled { break }

            await execute(identifier)

            if isCancelled { break }

            if isSizeOverLimit() {
                Log.info("2️⃣ \(Self.self): cancelling others, size exceeded.", domain: .photosProcessing)
                break
            }
        }
        context.completeCompoundsCreation()
        measurementRepository.stop()
        Log.info("2️⃣ \(Self.self): finished", domain: .photosProcessing)
    }

    private func isSizeOverLimit() -> Bool {
        sizeResource.getSize(of: context.createdCompounds) > sizeLimit
    }

    private func execute(_ identifier: PhotoIdentifier) async {
        do {
            let compounds = try await resource.execute(with: identifier)
            context.addCreated(compounds: compounds, identifier: identifier)
            let filesCount = compounds.reduce(0, { $0 + $1.secondary.count + 1 })
            skippableCache.recordFiles(identifier: identifier, filesToUpload: filesCount)
        } catch {
            handle(error: error, identifier: identifier)
        }
    }

    private func handle(error: Error, identifier: PhotoIdentifier) {
        switch errorPolicy.map(error: error) {
        case .temporaryError:
            context.addTemporaryError(identifier: identifier, error: error)
        case .missingAsset:
            context.addMissing(identifier: identifier)
        case let .updatedIdentifier(updatedIdentifier):
            context.replace(initialIdentifier: identifier, updatedIdentifier: updatedIdentifier)
        case .generic(let error):
            context.addGenericError(identifier: identifier, error: error)
        }
    }

    func cancel() {
        isCancelled = true
    }
}
