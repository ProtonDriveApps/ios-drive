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

actor PhotosAssetsInteractor: AsynchronousExecution {
    private static let maximumRetryTime = 3
    private let context: PhotosProcessingContext
    private let resource: PhotoLibraryAssetsResource
    private let sizeResource: PhotoCompoundsSizeResource
    private let errorPolicy: PhotoAssetErrorPolicy
    private let errorMappingPolicy: PhotosAssetsErrorMappingPolicy
    private let skippableCache: PhotosSkippableCache
    private let sizeLimit: Int
    private let measurementRepository: DurationMeasurementRepository
    private var isCancelled = false

    init(
        context: PhotosProcessingContext,
        resource: PhotoLibraryAssetsResource,
        sizeResource: PhotoCompoundsSizeResource,
        errorPolicy: PhotoAssetErrorPolicy,
        errorMappingPolicy: PhotosAssetsErrorMappingPolicy,
        skippableCache: PhotosSkippableCache,
        sizeLimit: Int,
        measurementRepository: DurationMeasurementRepository
    ) {
        self.context = context
        self.resource = resource
        self.sizeResource = sizeResource
        self.errorPolicy = errorPolicy
        self.errorMappingPolicy = errorMappingPolicy
        self.skippableCache = skippableCache
        self.sizeLimit = sizeLimit
        self.measurementRepository = measurementRepository
    }

    func execute() async {
        Log.info("2️⃣ \(Self.self): executing", domain: .photosProcessing)
        measurementRepository.start()
        for identifier in context.validIdentifiers {
            if isCancelled { break }

            await execute(identifier, retryCount: 0)

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

    private func execute(_ identifier: PhotoIdentifier, retryCount: Int) async {
        do {
            let compounds = try await resource.execute(with: identifier)
            context.addCreated(compounds: compounds, identifier: identifier)
            let filesCount = compounds.reduce(0, { $0 + $1.secondary.count + 1 })
            skippableCache.recordFiles(identifier: identifier, filesToUpload: filesCount)
        } catch {
            await handle(error: error, identifier: identifier, retryCount: retryCount)
        }
    }

    private func handle(error: Error, identifier: PhotoIdentifier, retryCount: Int) async {
        switch errorPolicy.map(error: error) {
        case .temporaryError:
            if retryCount < Self.maximumRetryTime {
                Log.error("Fetch resource failed, current retry count: \(retryCount), error: \(error.localizedDescription)", domain: .photosProcessing)
                let delayInSeconds = ExponentialBackoffWithJitter.getDelay(attempt: retryCount)
                let delayInNanoSeconds = delayInSeconds * Double(10 ^ 9)
                try? await Task.sleep(nanoseconds: UInt64(delayInNanoSeconds))
                await execute(identifier, retryCount: retryCount + 1)
            } else {
                Log.error("Failed to retry fetch resource \(Self.maximumRetryTime) times, skip it", domain: .photosProcessing)
                report(error: error, identifier: identifier)
            }
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
        Log.error(error, domain: .photosProcessing)
        let userError = errorMappingPolicy.map(error: error)
        context.addGenericError(identifier: identifier, error: userError)
    }
}
