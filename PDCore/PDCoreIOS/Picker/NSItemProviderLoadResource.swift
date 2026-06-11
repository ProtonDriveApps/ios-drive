// Copyright (c) 2025 Proton AG
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
import UniformTypeIdentifiers

public protocol ItemProviderLoadResource {
    func execute(with itemProvider: NSItemProvider, completion: @escaping (URLResult) -> Void)
}

public final class NSItemProviderLoadResource: ItemProviderLoadResource {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void

    private let copyURLFactory: (String) -> URL
    private let urlUsecase: NSItemProviderURLUsecase
    private let livePhotoUsecase: NSItemProviderLivePhotoUseCase
    private let imageUsecase: NSItemProviderImageUsecase
    private let textUsecase: NSItemProviderTextUsecase
    private let fileUsecase: NSItemProviderFileUsecase

    public init(copyURLFactory: @escaping (String) -> URL) {
        self.copyURLFactory = copyURLFactory
        self.urlUsecase = NSItemProviderURLUsecase(copyURLFactory: copyURLFactory)
        self.fileUsecase = NSItemProviderFileUsecase(copyURLFactory: copyURLFactory)
        self.imageUsecase = NSItemProviderImageUsecase(fileUsecase: fileUsecase, copyURLFactory: copyURLFactory)
        self.textUsecase = NSItemProviderTextUsecase(fileUsecase: fileUsecase, copyURLFactory: copyURLFactory)
        self.livePhotoUsecase = NSItemProviderLivePhotoUseCase(
            imageUseCase: imageUsecase,
            copyURLFactory: copyURLFactory
        )
    }

    public func execute(with itemProvider: NSItemProvider) async -> URLResult {
        await withCheckedContinuation { continuation in
            execute(with: itemProvider) { result in
                continuation.resume(returning: result)
            }
        }
    }

    public func execute(with itemProvider: NSItemProvider, completion: @escaping (URLResult) -> Void) {
        
        guard let typeIdentifier = availableTypeIdentifier(from: itemProvider) else  {
            Log.debug(
                "[Error] No available identifier from item provider, \(itemProvider.registeredTypeIdentifiers)",
                domain: .photoPicker
            )
            completion(.failure(Errors.noRegisteredTypeIdentifier))
            return
        }
        Log.info("Use identifier \(typeIdentifier)", domain: .itemProviderLoader)
        execute(with: itemProvider, typeIdentifier: typeIdentifier, completion: completion)
    }

    private func availableTypeIdentifier(from itemProvider: NSItemProvider) -> String? {
        let identifiers = itemProvider.registeredTypeIdentifiers

        let preferredImageTypes: [UTType] = [.heic, .heif, .rawImage, .tiff, .png, .webP]
        for preferred in preferredImageTypes where identifiers.contains(preferred.identifier) {
            return preferred.identifier
        }

        for identifier in identifiers where itemProvider.hasRepresentationConforming(toTypeIdentifier: identifier) {
            // e.g. "com.apple.private.photos.thumbnail.standard"
            if identifier.contains("thumbnail") { continue }
            return identifier
        }
        return identifiers.first
    }

    private func execute(with itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping (URLResult) -> Void) {
        let uti = UTI(value: typeIdentifier)
        Log.debug("Parsing \(uti)", domain: .itemProviderLoader)
        if uti.isLiveAsset {
            livePhotoUsecase.load(itemProvider) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        } else if isURLType(typeIdentifier) {
            urlUsecase.load(itemProvider) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        } else if uti.isImage {
            imageUsecase.load(itemProvider, typeIdentifier: typeIdentifier) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        } else if uti.isText {
            textUsecase.load(itemProvider, typeIdentifier: typeIdentifier) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        } else {
            fileUsecase.load(itemProvider, typeIdentifier: typeIdentifier) { [weak self] result in
                self?.finish(with: result, completion: completion)
            }
        }
    }

    private func isURLType(_ typeIdentifier: String) -> Bool {
        guard let type = UTType(typeIdentifier) else { return false }
        return type.conforms(to: .url)
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
                Log.error(error: error, domain: .photoPicker)
                return .failure(error)
            }
            return .success(URLContent(url, size))
        case let (nil, error?):
            let text = "Couldn't load files"
            Log.error(text, error: error, domain: .photoPicker)
            return .failure(error)
        default:
            return .failure(Errors.invalidState)
        }
    }

    public enum Errors: Error {
        case noRegisteredTypeIdentifier
        case invalidState
        /// file path to the file
        case unsupportedHTML(URL)
    }
}
