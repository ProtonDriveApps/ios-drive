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
import Foundation
import Photos
import PDPhotos

actor PhotosAssetsInteractor: AsynchronousExecution {
    private let context: PhotosProcessingContext
    private let resource: PhotoLibraryAssetsResource
    private let errorPolicy: PhotoAssetErrorPolicy
    private let errorMappingPolicy: PhotosAssetsErrorMappingPolicy
    private let skippableCache: PhotosSkippableCache
    private let sizeLimit: Int
    private let measurementRepository: DurationMeasurementRepository
    private var isCancelled = false
    private let optionsFactory: PHFetchOptionsFactory
    private let photoAssetsFetcher: ([String], PHFetchOptions?) -> PHFetchResult<PHAsset>

    init(
        context: PhotosProcessingContext,
        resource: PhotoLibraryAssetsResource,
        errorPolicy: PhotoAssetErrorPolicy,
        errorMappingPolicy: PhotosAssetsErrorMappingPolicy,
        skippableCache: PhotosSkippableCache,
        sizeLimit: Int,
        measurementRepository: DurationMeasurementRepository,
        optionsFactory: PHFetchOptionsFactory,
        photoAssetsFetcher: @escaping ([String], PHFetchOptions?) -> PHFetchResult<PHAsset> = { PHAsset.fetchAssets(withLocalIdentifiers: $0, options: $1) }
    ) {
        self.context = context
        self.resource = resource
        self.errorPolicy = errorPolicy
        self.errorMappingPolicy = errorMappingPolicy
        self.skippableCache = skippableCache
        self.sizeLimit = sizeLimit
        self.measurementRepository = measurementRepository
        self.optionsFactory = optionsFactory
        self.photoAssetsFetcher = photoAssetsFetcher
    }

    func execute() async {
        Log.info("2️⃣ executing", domain: .photosProcessing)
        measurementRepository.start()

        let identifiers = context.validIdentifiers
        let result = loadPhotoAssets(from: identifiers)
        result.missingIdentifier.forEach { context.addMissing(identifier: $0) }
        for data in result.mapping {
            // Can't run this async, otherwise `PHImageManager` won't return data
            let result = await self.execute(data.0, asset: data.1)
            if let error = result.error {
                handle(error: error, identifier: result.identifier)
            } else {
                context.addCreated(compounds: result.compounds, identifier: result.identifier)
                skippableCache.recordFiles(identifier: result.identifier, filesToUpload: result.filesCount)
            }
        }

        context.completeCompoundsCreation()
        measurementRepository.stop()
        Log.info("2️⃣ finished", domain: .photosProcessing)
    }

    private func execute(_ identifier: PhotoIdentifier, asset: PHAsset) async -> AssetCompoundResult {
        do {
            let compounds = try await resource.execute(with: identifier, asset: asset)
            let filesCount = compounds.reduce(0, { $0 + $1.secondary.count + 1 })
            return AssetCompoundResult(identifier: identifier, compounds: compounds, filesCount: filesCount, error: nil)
        } catch {
            return AssetCompoundResult(identifier: identifier, compounds: [], filesCount: -1, error: error)
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
            report(error: error, identifier: identifier)
        }
    }

    func cancel() {
        isCancelled = true
    }

    private func report(error: Error, identifier: PhotoIdentifier) {
        Log.error(error: error, domain: .photosProcessing)
        let userError = errorMappingPolicy.map(error: error)
        context.addGenericError(identifier: identifier, error: userError)
    }

    private func loadPhotoAssets(from identifiers: Set<PhotoIdentifier>) -> AssetLoadResult {
        let localIDs = identifiers.map(\.localIdentifier)
        if localIDs.isEmpty { return .init(mapping: [], missingIdentifier: []) }
        let options = optionsFactory.makeOptions()
        let fetchResult = photoAssetsFetcher(localIDs, options)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        var mapping: [(PhotoIdentifier, PHAsset)] = []
        var missingIdentifiers: [PhotoIdentifier] = []
        for id in identifiers {
            guard let asset = assets.first(where: { $0.localIdentifier == id.localIdentifier }) else {
                missingIdentifiers.append(id)
                continue
            }
            mapping.append((id, asset))
        }
        return .init(mapping: mapping, missingIdentifier: missingIdentifiers)
    }
}

extension PhotosAssetsInteractor {
    struct AssetLoadResult {
        let mapping: [(PhotoIdentifier, PHAsset)]
        let missingIdentifier: [PhotoIdentifier]
    }

    struct AssetCompoundResult {
        let identifier: PhotoIdentifier
        let compounds: [PhotoAssetCompound]
        let filesCount: Int
        let error: Error?
    }
}
