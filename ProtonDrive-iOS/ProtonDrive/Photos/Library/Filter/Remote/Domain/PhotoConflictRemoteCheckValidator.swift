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

protocol PhotoConflictRemoteCheckValidator {
    func validate(localItem: PhotosFilterItem, remoteItems: [PhotoRemoteDuplicateCheckItem]) throws -> PhotoConflictRemoteCheckResult
}

enum PhotoConflictRemoteCheckResult: Equatable {
    case skip
    case upload
    case partialUpload(primaryUploadID: String, secondary: [PhotoAsset])
}

final class ConcretePhotoConflictRemoteCheckValidator: PhotoConflictRemoteCheckValidator {
    private let hashInteractor: PhotoContentHashInteractor
    private let clientUIDProvider: UploadClientUIDProvider
    private let linkIdRepository: LocalPhotoLinkIdRepository

    // TODO: some of the dependencies are not used now, but are necessary for handling drafts
    init(hashInteractor: PhotoContentHashInteractor, clientUIDProvider: UploadClientUIDProvider, linkIdRepository: LocalPhotoLinkIdRepository) {
        self.hashInteractor = hashInteractor
        self.clientUIDProvider = clientUIDProvider
        self.linkIdRepository = linkIdRepository
    }

    func validate(localItem: PhotosFilterItem, remoteItems: [PhotoRemoteDuplicateCheckItem]) throws -> PhotoConflictRemoteCheckResult {
        let primaryLocalHash = try makeHash(from: localItem.primary)

        guard !remoteItems.contains(where: { $0.hash == primaryLocalHash.nameHash && $0.linkState == .draft }) else {
            // TODO: We're not considering drafts in this moment, requires more complex changes.
            Log.debug("Duplicate check: draft primary: \(primaryLocalHash.nameHash)", domain: .photosProcessing)
            return .skip
        }

        guard let primaryRemoteItem = remoteItems.first(where: { areHashesMatching(localItem: primaryLocalHash, remoteItem: $0) }) else {
            // There is no primary in BE -> we can upload this whole compound
            Log.debug("Duplicate check: new compound with primary: \(primaryLocalHash.nameHash)", domain: .photosProcessing)
            return .upload
        }

        switch primaryRemoteItem.linkState {
        case .draft:
            // TODO: Will not happen because we're filtering out drafts above
            Log.debug("Duplicate check: draft primary: \(primaryLocalHash.nameHash)", domain: .photosProcessing)
            return .skip
        case .active, .trashed:
            return try validateActiveOrTrashed(primaryItem: primaryRemoteItem, primaryLocalHash: primaryLocalHash, localItem: localItem, remoteItems: remoteItems)
        case nil:
            return try validateNilPrimary(primaryLocalHash: primaryLocalHash, localItem: localItem)
        }
    }

    private func validateActiveOrTrashed(primaryItem: PhotoRemoteDuplicateCheckItem, primaryLocalHash: PhotoHashes, localItem: PhotosFilterItem, remoteItems: [PhotoRemoteDuplicateCheckItem]) throws -> PhotoConflictRemoteCheckResult {
        guard let primaryLinkId = primaryItem.linkID else {
            // Inconsistent data (missing primary link id). Skipping compound.
            Log.error(DriveError("Duplicate check: missing primary link id: \(primaryLocalHash.nameHash)"), domain: .photosProcessing)
            return .skip
        }

        let secondaryCheck = try validateSecondary(localItem: localItem, remoteItems: remoteItems)
        let nameHashes = localItem.allIdentifiers.map { $0.nameHash }
        switch secondaryCheck {
        case .skip:
            // All secondary are uploaded. Skip it.
            Log.debug("Duplicate check: nothing to add, skipping: \(nameHashes)", domain: .photosProcessing)
            return .skip
        case let .upload(secondary):
            // Some secondary need to be reuploaded.
            Log.debug("Duplicate check: some secondary missing: \(nameHashes)", domain: .photosProcessing)
            return .partialUpload(primaryUploadID: primaryLinkId, secondary: secondary)
        }
    }

    private func validateNilPrimary(primaryLocalHash: PhotoHashes, localItem: PhotosFilterItem) throws -> PhotoConflictRemoteCheckResult {
        // Deleted primary -> so we know the user actively deleted it. No need to check the secondary.
        Log.debug("Duplicate check: deleted item on BE: \(primaryLocalHash.nameHash)", domain: .photosProcessing)
        return .skip
    }

    enum PhotoPartialConflictRemoteCheckResult {
        case skip
        case upload([PhotoAsset])
    }

    private func validateSecondary(localItem: PhotosFilterItem, remoteItems: [PhotoRemoteDuplicateCheckItem]) throws -> PhotoPartialConflictRemoteCheckResult {
        var validIdentifiers = [PhotoAssetIdentifier]()
        for identifier in localItem.secondary {
            let hash = try makeHash(from: identifier)

            // TODO: if there is draft match, we just skip it and don't validate the clientUID etc.
            let isUploaded = remoteItems.contains {
                $0.hash == hash.nameHash && ($0.contentHash == hash.contentHash || $0.linkState == .draft)
            }
            if !isUploaded {
                // There's missing secondary
                validIdentifiers.append(identifier)
            }
        }

        if validIdentifiers.isEmpty {
            return .skip
        } else {
            return .upload(validIdentifiers.map(\.asset))
        }
    }

    private func areHashesMatching(localItem: PhotoHashes, remoteItem: PhotoRemoteDuplicateCheckItem) -> Bool {
        return remoteItem.hash == localItem.nameHash && remoteItem.contentHash == localItem.contentHash
    }

    private func makeHash(from identifier: PhotoAssetIdentifier) throws -> PhotoHashes {
        let contentHash = try hashInteractor.makeContentHash(from: identifier.url)
        return PhotoHashes(nameHash: identifier.nameHash, contentHash: contentHash)
    }
}
