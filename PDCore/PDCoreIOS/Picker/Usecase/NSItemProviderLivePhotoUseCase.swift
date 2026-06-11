// Copyright (c) 2026 Proton AG
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
import Photos
import PDCore

struct NSItemProviderLivePhotoUseCase {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void
    private let copyURLFactory: (String) -> URL
    private let imageUseCase: NSItemProviderImageUsecase

    init(imageUseCase: NSItemProviderImageUsecase, copyURLFactory: @escaping (String) -> URL) {
        self.copyURLFactory = copyURLFactory
        self.imageUseCase = imageUseCase
    }

    func load(_ itemProvider: NSItemProvider, completion: @escaping URLErrorCompletion) {
        Log.info("Loading item provider with LivePhoto type", domain: .itemProviderLoader)
        itemProvider.loadObject(ofClass: PHLivePhoto.self) { reading, error in
            guard let resource = getPhotoResource(from: reading) else {
                Log.info("Load live photo failed, fallback to load image", domain: .itemProviderLoader)
                // If live photo load fails, we try to load the image representation instead.
                let utTypeIdentifiers = itemProvider.registeredTypeIdentifiers.map { UTI(value: $0) }
                if let typeIdentifier = utTypeIdentifiers.first(where: { !$0.isLiveAsset && $0.isImage })?.value {
                    imageUseCase.load(itemProvider, typeIdentifier: typeIdentifier, completion: completion)
                } else {
                    completion((nil, Errors.noRegisteredTypeIdentifier))
                }
                return
            }

            let copyURL = copyURLFactory(resource.originalFilename)
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: copyURL, options: options) { error in
                if let error = error {
                    completion((nil, error))
                } else {
                    completion((copyURL, nil))
                }
            }
        }
    }

    private func getPhotoResource(from reading: NSItemProviderReading?) -> PHAssetResource? {
        guard let livePhoto = reading as? PHLivePhoto else { return nil }
        return PHAssetResource.assetResources(for: livePhoto)
            .first(where: { $0.type == .photo })
    }

    enum Errors: Error {
        case noRegisteredTypeIdentifier
    }
}
