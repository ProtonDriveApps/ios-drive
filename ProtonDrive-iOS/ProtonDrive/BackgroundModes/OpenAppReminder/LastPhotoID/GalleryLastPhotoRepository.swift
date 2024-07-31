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

import Photos
import PDCore

final class GalleryLastPhotoRepository: LastPhotoRepository {

    private let authorizationStatusChecker: (PHAccessLevel) -> PHAuthorizationStatus
    private let photoAssetsFetcher: (PHFetchOptions?) -> PHFetchResult<PHAsset>
    private let cloudIdentifierMapper: ([String]) -> [String: Result<PHCloudIdentifier, any Error>]

    init(
        authorizationStatusChecker: @escaping (PHAccessLevel) -> PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for:),
        photoAssetsFetcher: @escaping (PHFetchOptions?) -> PHFetchResult<PHAsset> = PHAsset.fetchAssets(with:),
        cloudIdentifierMapper: @escaping ([String]) -> [String: Result<PHCloudIdentifier, any Error>] = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers:)
    ) {
        self.authorizationStatusChecker = authorizationStatusChecker
        self.photoAssetsFetcher = photoAssetsFetcher
        self.cloudIdentifierMapper = cloudIdentifierMapper
    }

    func getLastPhotoID() throws -> String {
        guard checkAuthorizationstatus(forLevel: .readWrite) == .authorized else {
            throw CheckGalleryError.unauthorized
        }

        // Create a fetch options
        let fetchOptions = PHFetchOptions.defaultPhotosOptions()
        fetchOptions.fetchLimit = 1

        // Fetch the assets
        let fetchResult = fetchPhotoAssets(withOptions: fetchOptions)

        guard let localIdentifier = fetchResult.firstObject?.localIdentifier else {
            throw CheckGalleryError.emptyGallery
        }

        let cloudIdentifiers = mapToCloudIdentifiers(localIdentifiers: [localIdentifier])

        guard let cloudIdentifier = cloudIdentifiers[localIdentifier] else {
            throw CheckGalleryError.inconsistentCloudID
        }

        return try cloudIdentifier.get().stringValue
    }

    private func checkAuthorizationstatus(forLevel level: PHAccessLevel) -> PHAuthorizationStatus {
        authorizationStatusChecker(level)
    }

    private func fetchPhotoAssets(withOptions fetchOptions: PHFetchOptions?) -> PHFetchResult<PHAsset> {
        photoAssetsFetcher(fetchOptions)
    }

    private func mapToCloudIdentifiers(localIdentifiers: [String]) -> [String: Result<PHCloudIdentifier, any Error>] {
        cloudIdentifierMapper(localIdentifiers)
    }
}
