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

import PDClient
import PDCore

struct PhotoAssetCompoundNameConflictsResult {
    let validCompounds: [PhotoAssetCompound]
    let failedCompounds: [PhotosFailedCompound]
    let conflictingItems: [PhotosFilterItem]
    let remoteItems: [PhotoRemoteDuplicateCheckItem]
}

typealias PhotoRemoteDuplicateCheckItem = FindDuplicatesResponse.Item

protocol PhotoNameConflictsInteractor {
    func execute(with compounds: [PhotoAssetCompound]) async throws -> PhotoAssetCompoundNameConflictsResult
}

final class RemotePhotoNameConflictsInteractor: PhotoNameConflictsInteractor {
    private let identifiersInteractor: PhotoAssetIdentifiersInteractor
    private let volumeIdDataSource: PhotosVolumeIdDataSource
    private let duplicatesRepository: PhotosDuplicatesRepository
    private let nameHashesStrategy: PhotoConflictNameHashesStrategy
    private let circuitBreaker: CircuitBreakerController

    init(identifiersInteractor: PhotoAssetIdentifiersInteractor, volumeIdDataSource: PhotosVolumeIdDataSource, duplicatesRepository: PhotosDuplicatesRepository, nameHashesStrategy: PhotoConflictNameHashesStrategy, circuitBreaker: CircuitBreakerController) {
        self.identifiersInteractor = identifiersInteractor
        self.volumeIdDataSource = volumeIdDataSource
        self.duplicatesRepository = duplicatesRepository
        self.nameHashesStrategy = nameHashesStrategy
        self.circuitBreaker = circuitBreaker
    }

    func execute(with compounds: [PhotoAssetCompound]) async throws -> PhotoAssetCompoundNameConflictsResult {
        let data = makeData(from: compounds)
        let allIdentifiers = data.items.flatMap(\.allIdentifiers)
        let remoteItems = try await getRemoteItems(for: allIdentifiers)
        return filter(data: data, remoteItems: remoteItems)
    }

    private func filter(data: PhotosFilterCompounds, remoteItems: [PhotoRemoteDuplicateCheckItem]) -> PhotoAssetCompoundNameConflictsResult {
        var validCompounds = [PhotoAssetCompound]()
        var conflictingItems = [PhotosFilterItem]()
        data.items.forEach { item in
            do {
                try nameHashesStrategy.validate(item: item, remoteItems: remoteItems)
                validCompounds.append(item.compound)
            } catch {
                conflictingItems.append(item)
            }
        }
        return PhotoAssetCompoundNameConflictsResult(
            validCompounds: validCompounds,
            failedCompounds: data.failedCompounds,
            conflictingItems: conflictingItems,
            remoteItems: remoteItems
        )
    }

    private func makeData(from compounds: [PhotoAssetCompound]) -> PhotosFilterCompounds {
        var validItems = [PhotosFilterItem]()
        var failedCompounds = [PhotosFailedCompound]()
        compounds.forEach { compound in
            do {
                let item = try identifiersInteractor.getIdentifiers(from: compound)
                validItems.append(item)
            } catch {
                Log.error(DriveError(withDomainAndCode: error, message: error.localizedDescription), domain: .photosProcessing)

                let userError = mapToUserError(error: error)
                failedCompounds.append(.init(compound: compound, error: userError))
            }
        }
        return PhotosFilterCompounds(items: validItems, failedCompounds: failedCompounds)
    }

    private func getRemoteItems(for identifiers: [PhotoAssetIdentifier]) async throws -> [PhotoRemoteDuplicateCheckItem] {
        let volumeId = try await volumeIdDataSource.getVolumeId()
        let localHashes = identifiers.map(\.nameHash)
        var remoteItems = [PhotoRemoteDuplicateCheckItem]()
        let batches = localHashes.splitInGroups(of: 150)
        for batch in batches {
            let parameters = FindDuplicatesParameters(volumeId: volumeId, nameHashes: batch)
            do {
                let response = try await duplicatesRepository.getPhotosDuplicates(with: parameters)
                remoteItems += response.duplicateHashes
            } catch {
                circuitBreaker.handleError(error)
                throw error
            }
        }
        return remoteItems
    }
    
    // Errors from the interactor can be quite complex,
    // especially those originating from the crypto library.
    // Apply this straightforward logic to differentiate between them.
    private func mapToUserError(error: Error) -> PhotosFailureUserError {
        if error is ValidationError<String> {
            return .nameValidationError
        } else {
            return .encryptionFailed
        }
    }
}
