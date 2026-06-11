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
import UIKit
import UniformTypeIdentifiers
import PDCore

// Especially for images shared from Viber and Facebook Messenger
struct NSItemProviderImageUsecase: NSItemProviderLoadUsecase {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void
    private let copyURLFactory: (String) -> URL
    private let fileUsecase: NSItemProviderFileUsecase

    init(fileUsecase: NSItemProviderFileUsecase, copyURLFactory: @escaping (String) -> URL) {
        self.fileUsecase = fileUsecase
        self.copyURLFactory = copyURLFactory
    }

    func load(_ itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping URLErrorCompletion) {
        Log.info("Loading item provider with Image type \(typeIdentifier)", domain: .itemProviderLoader)
        loadImageName(itemProvider, typeIdentifier: typeIdentifier) { filename in
            itemProvider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                guard let data else {
                    completion((nil, error))
                    return
                }

                guard let imageData = imageData(from: data) else {
                    completion((nil, error ?? Errors.invalidState))
                    return
                }

                // filename from `loadImageName` not always has file extension
                // Take Viber as an example: the filename doesn’t include an extension, and the data is an archived object
                // We therefore treat it as PNG and use "png" as the default extension
                var filename = filename ?? defaultFilename(typeIdentifier: typeIdentifier)
                filename = appendFileExtensionIfNeeded(filename: filename, typeIdentifier: typeIdentifier, defaultExtension: "png")
                let copyURL = copyURLFactory(filename)

                do {
                    try imageData.write(to: copyURL, options: .atomic)
                    completion((copyURL, nil))
                } catch {
                    completion((nil, error))
                }
            }
        }
    }

    private func loadImageName(
        _ itemProvider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (String?) -> Void
    ) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            guard let url else {
                completion(nil)
                return
            }
            let name = fileUsecase.filename(
                typeIdentifier: typeIdentifier,
                sourceURL: url
            )
            completion(name)
        }
    }

    private func imageData(from data: Data) -> Data? {
        if UIImage(data: data) != nil {
            return data
        } else if let image = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIImage.self, from: data) {
            return image.pngData()
        }

        return nil
    }

    private func defaultFilename(typeIdentifier: String) -> String {
        let name = defaultFilename(suffix: "image")
        return appendFileExtensionIfNeeded(filename: name, typeIdentifier: typeIdentifier, defaultExtension: "png")
    }

    enum Errors: Error {
        case noRegisteredTypeIdentifier
        case invalidState
    }
}
