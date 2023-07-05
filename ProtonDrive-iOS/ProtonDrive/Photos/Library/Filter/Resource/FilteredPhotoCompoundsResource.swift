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
import CoreData
import PDCore

struct FilteredPhotoCompoundsResult {
    let compounds: [PhotoAssetCompound]
    let validIdentifiersCount: Int
    let invalidIdentifiersCount: Int
}

protocol FilteredPhotoCompoundsResource {
    var result: AnyPublisher<FilteredPhotoCompoundsResult, Never> { get }
    func execute(with compounds: [PhotoAssetCompound])
}

final class DatabaseFilteredPhotoCompoundsResource: FilteredPhotoCompoundsResource {
    private let storage: StorageManager
    private let resultSubject = PassthroughSubject<FilteredPhotoCompoundsResult, Never>()

    var result: AnyPublisher<FilteredPhotoCompoundsResult, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    init(storage: StorageManager) {
        self.storage = storage
    }

    func execute(with compounds: [PhotoAssetCompound]) {
        Task {
            await filter(compounds: compounds)
        }
    }

    private func filter(compounds: [PhotoAssetCompound]) async {
        let photos = fetchPhotos()
        var validCompounds = [PhotoAssetCompound]()
        var invalidCompounds = [PhotoAssetCompound]()
        compounds.forEach { compound in
            if photos.contains(where: { isEqual(compound: compound, photo: $0) }) {
                invalidCompounds.append(compound)
            } else {
                validCompounds.append(compound)
            }
        }
        invalidCompounds.forEach(cleanUpInvalidCompound)
        let result = makeResult(valid: validCompounds, invalid: invalidCompounds)
        await finish(with: result)
    }

    private func fetchPhotos() -> [Photo] {
        let managedObjectContext = storage.backgroundContext
        return storage.fetchPrimaryPhotos(moc: managedObjectContext)
    }

    private func makeResult(valid: [PhotoAssetCompound], invalid: [PhotoAssetCompound]) -> FilteredPhotoCompoundsResult {
        FilteredPhotoCompoundsResult(
            compounds: valid,
            validIdentifiersCount: valid.count,
            invalidIdentifiersCount: invalid.count
        )
    }

    private func cleanUpInvalidCompound(_ compound: PhotoAssetCompound) {
        let assets = [compound.primary] + compound.secondary
        assets.forEach {
            try? FileManager.default.removeItem(at: $0.url)
        }
    }

    private func isEqual(compound: PhotoAssetCompound, photo: Photo) -> Bool {
        storage.backgroundContext.performAndWait {
            guard compound.secondary.count == photo.children.count else {
                return false
            }

            guard isEqual(asset: compound.primary, photo: photo) else {
                return false
            }

            return !areDifferent(assets: compound.secondary, photos: photo.children)
        }
    }

    private func areDifferent(assets: [PhotoAsset], photos: Set<Photo>) -> Bool {
        return assets.contains { asset in
            !isContained(asset: asset, in: photos)
        }
    }

    private func isContained(asset: PhotoAsset, in photos: Set<Photo>) -> Bool {
        return photos.contains { photo in
            isEqual(asset: asset, photo: photo)
        }
    }

    private func isEqual(asset: PhotoAsset, photo: Photo) -> Bool {
        return asset.filename == photo.decryptedName && asset.contentHash == getContentHash(from: photo)
    }

    private func getContentHash(from photo: Photo) -> String? {
        return try? photo.photoRevision.decryptExtendedAttributes().common?.digests?.sha1
    }

    @MainActor
    private func finish(with result: FilteredPhotoCompoundsResult) {
        resultSubject.send(result)
    }
}
