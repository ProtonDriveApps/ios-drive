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

struct FilteredPhotoCompoundsResult {
    let validCompounds: [PhotoAssetCompound]
    let validPartialCompounds: [PartialPhotoAssetCompound]
    let invalidCompounds: [PhotoAssetCompound]
    let invalidAssets: [PhotoAsset]
    let failedCompounds: [PhotoAssetCompound]
}

protocol PhotoAssetCompoundsConflictInteractor {
    func execute(with input: [PhotoAssetCompound]) async throws -> FilteredPhotoCompoundsResult
}

final class ConcretePhotoAssetCompoundsConflictInteractor: PhotoAssetCompoundsConflictInteractor {
    private let nameConflictsInteractor: PhotoNameConflictsInteractor
    private let contentConflictsInteractor: PhotoContentConflictsInteractor

    init(nameConflictsInteractor: PhotoNameConflictsInteractor, contentConflictsInteractor: PhotoContentConflictsInteractor) {
        self.nameConflictsInteractor = nameConflictsInteractor
        self.contentConflictsInteractor = contentConflictsInteractor
    }

    func execute(with input: [PhotoAssetCompound]) async throws -> FilteredPhotoCompoundsResult {
        let namesResult = try await executeNamesCheck(with: input)
        guard !namesResult.conflictingItems.isEmpty else {
            return FilteredPhotoCompoundsResult(
                validCompounds: namesResult.validCompounds,
                validPartialCompounds: [],
                invalidCompounds: [],
                invalidAssets: [],
                failedCompounds: namesResult.failedCompounds
            )
        }
        let contentsResult = contentConflictsInteractor.execute(items: namesResult.conflictingItems, remoteItems: namesResult.remoteItems)
        let validCompounds = namesResult.validCompounds + contentsResult.validCompounds
        return FilteredPhotoCompoundsResult(
            validCompounds: validCompounds,
            validPartialCompounds: contentsResult.validPartialCompounds,
            invalidCompounds: contentsResult.invalidCompounds,
            invalidAssets: contentsResult.invalidAssets,
            failedCompounds: namesResult.failedCompounds + contentsResult.failedCompounds
        )

    }

    private func executeNamesCheck(with input: [PhotoAssetCompound]) async throws -> PhotoAssetCompoundNameConflictsResult {
        try await nameConflictsInteractor.execute(with: input)
    }
}
