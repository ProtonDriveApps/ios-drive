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

import Foundation
import PDClient
import PDCore

protocol PhotoContentConflictsInteractor {
    func execute(items: [PhotosFilterItem], remoteItems: [PhotoRemoteDuplicateCheckItem]) -> FilteredPhotoCompoundsResult
}

final class RemotePhotoContentConflictsInteractor: PhotoContentConflictsInteractor {
    private let validator: PhotoConflictRemoteCheckValidator

    init(validator: PhotoConflictRemoteCheckValidator) {
        self.validator = validator
    }

    func execute(items: [PhotosFilterItem], remoteItems: [PhotoRemoteDuplicateCheckItem]) -> FilteredPhotoCompoundsResult {
        var validCompounds = [PhotoAssetCompound]()
        var validPartialCompounds = [PartialPhotoAssetCompound]()
        var invalidCompounds = [PhotoAssetCompound]()
        var failedCompounds = [PhotosFailedCompound]()
        var invalidAssets = [PhotoAsset]()
        for item in items {
            let compound = item.compound
            do {
                let result = try validator.validate(localItem: item, remoteItems: remoteItems)
                switch result {
                case .skip:
                    invalidCompounds.append(compound)
                case .upload:
                    validCompounds.append(compound)
                case let .partialUpload(primaryLinkId, secondary):
                    let partialCompound = PartialPhotoAssetCompound(primaryLinkId: primaryLinkId, secondary: secondary, originalCompound: compound)
                    validPartialCompounds.append(partialCompound)
                    let invalidCompoundAssets = compound.allAssets.filter { !secondary.contains($0) }
                    invalidAssets += invalidCompoundAssets
                }
            } catch {
                Log.error(DriveError(withDomainAndCode: error, message: "\(self.self)"), domain: .photosProcessing)
                
                // Errors from the validator are due to hash generation.
                // Simplify by using encryption errors.
                failedCompounds.append(.init(compound: compound, error: .encryptionFailed))
            }
        }
        return FilteredPhotoCompoundsResult(
            validCompounds: validCompounds,
            validPartialCompounds: validPartialCompounds,
            invalidCompounds: invalidCompounds,
            invalidAssets: invalidAssets,
            failedCompounds: failedCompounds
        )
    }
}
