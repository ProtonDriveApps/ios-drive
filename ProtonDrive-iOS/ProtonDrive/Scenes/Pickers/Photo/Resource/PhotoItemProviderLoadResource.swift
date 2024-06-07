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
import os.log
import PDCore
import Photos

protocol ItemProviderLoadResource {
    func execute(with itemProvider: NSItemProvider, completion: @escaping (URLResult) -> Void)
}

final class PhotoItemProviderLoadResource: ItemProviderLoadResource, LogObject {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void
    static var osLog = OSLog(subsystem: "ProtonDrive", category: "PhotoItemProviderResource")

    func execute(with itemProvider: NSItemProvider, completion: @escaping (URLResult) -> Void) {
        guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first else  {
            completion(.failure(Errors.noRegisteredTypeIdentifier))
            return
        }

        execute(with: itemProvider, typeIdentifier: typeIdentifier, completion: completion)
    }
    
    private func execute(with itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping (URLResult) -> Void) {
        if UTI(value: typeIdentifier).isLiveAsset {
            loadLivePhoto(with: itemProvider) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        } else {
            loadFileRepresentation(with: itemProvider, typeIdentifier: typeIdentifier) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        }
    }
    
    private func finish(with result: (URL?, Error?), completion: @escaping (URLResult) -> Void) {
        let result = map(result: result)
        completion(result)
    }
    
    private func map(result: (URL?, Error?)) -> URLResult {
        switch result {
        case let (url?, nil):
            guard let size = url.fileSize else {
                let error = URLConsistencyError.noURLSize
                Log.error(error, domain: .photoPicker)
                return .failure(error)
            }
            return .success(URLContent(url, size))
        case let (nil, error?):
            let nsError = error as NSError
            let text = "Couldn't load image from picker. Code: \(nsError.code), domain: \(nsError.domain)"
            Log.error(text, domain: .photoPicker)
            return .failure(error)
        default:
            return .failure(Errors.invalidState)
        }
    }
    
    private func loadLivePhoto(with itemProvider: NSItemProvider, completion: @escaping URLErrorCompletion) {
        itemProvider.loadObject(ofClass: PHLivePhoto.self) { [weak self] reading, error in
            guard let resource = self?.getPhotoResource(from: reading) else {
                // If live photo load fails, we try to load the image representation instead.
                let utTypeIdentifiers = itemProvider.registeredTypeIdentifiers.map { UTI(value: $0) }
                let typeIdentifier = utTypeIdentifiers.first(where: { !$0.isLiveAsset && $0.isImage })?.value ?? ""
                self?.loadFileRepresentation(with: itemProvider, typeIdentifier: typeIdentifier, completion: completion)
                return
            }

            let copyURL = PDFileManager.prepareUrlForFile(named: resource.originalFilename)
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
        guard let livePhoto = reading as? PHLivePhoto else {
            return nil
        }

        return PHAssetResource.assetResources(for: livePhoto).first(where: { $0.type == .photo })
    }
    
    private func loadFileRepresentation(with itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping URLErrorCompletion) {
        // Trying loadInPlace version doesn't work for some reason. Documentation doesn't say anything about exceptions.
        // The log we get is:
        // [UI] loadInPlaceFileRepresentationForTypeIdentifier: is not supported. Use loadFileRepresentationForTypeIdentifier: instead.
        itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            if let url = url {
                self?.copyToLocalStorage(url: url, completion: completion)
            } else {
                completion((nil, error))
            }
        }
    }

    private func copyToLocalStorage(url: URL, completion: @escaping URLErrorCompletion) {
        do {
            let copyURL = PDFileManager.prepareUrlForFile(named: url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: copyURL)
            completion((copyURL, nil))
        } catch {
            completion((nil, error))
        }
    }
    
    enum Errors: Error {
        case noRegisteredTypeIdentifier
        case invalidState
    }
}
