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
import PDCore
import Photos

protocol PhotoLibraryFileContentResource {
    func copyFile(with resource: PHAssetResource) async throws -> URL
    func createHash(with resource: PHAssetResource) async throws -> Data
}

final class LocalPhotoLibraryFileContentResource: PhotoLibraryFileContentResource {
    private let digestBuilderFactory: () -> DigestBuilder // Needs to be a factory because every hash operation needs unique builder

    init(digestBuilderFactory: @escaping () -> DigestBuilder) {
        self.digestBuilderFactory = digestBuilderFactory
    }

    func copyFile(with resource: PHAssetResource) async throws -> URL {
        let url = PDFileManager.prepareUrlForPhotoFile(named: resource.originalFilename)
        let options = makeOptions()
        try await PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options)
        return url
    }

    func createHash(with resource: PHAssetResource) async throws -> Data {
        let builder = digestBuilderFactory()
        let options = makeOptions()
        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().requestData(for: resource, options: options) { data in
                builder.add(data)
            } completionHandler: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let hash = builder.getResult()
                    continuation.resume(returning: hash)
                }
            }
        }
    }

    private func makeOptions() -> PHAssetResourceRequestOptions {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        return options
    }
}
