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
import PDCore
import UniformTypeIdentifiers

struct NSItemProviderFileUsecase: NSItemProviderLoadUsecase {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void
    private let copyURLFactory: (String) -> URL

    init(copyURLFactory: @escaping (String) -> URL) {
        self.copyURLFactory = copyURLFactory
    }

    func load(_ itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping URLErrorCompletion) {
        Log.info("Loading item provider with file type", domain: .itemProviderLoader)
        // Trying loadInPlace version doesn't work for some reason. Documentation doesn't say anything about exceptions.
        // The log we get is:
        // [UI] loadInPlaceFileRepresentationForTypeIdentifier: is not supported. Use loadFileRepresentationForTypeIdentifier: instead.
        let identifiers = itemProvider.registeredTypeIdentifiers
        itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            guard let url else {
                let desc = error?.localizedDescription ?? "Unknown error"
                Log.debug(
                    "[Error] Load representation failed: \(desc), all registered identifiers: \(identifiers)",
                    domain: .itemProviderLoader
                )
                completion((nil, error))
                return
            }

            let filename = filename(typeIdentifier: typeIdentifier, sourceURL: url)

            do {
                let copyURL = copyURLFactory(filename)
                try FileManager.default.moveItem(at: url, to: copyURL)
                completion((copyURL, nil))
            } catch {
                completion((nil, error))
            }
        }
    }

    public func filename(typeIdentifier: String, sourceURL: URL) -> String {
        let baseName: String
        if !sourceURL.lastPathComponent.isEmpty {
            baseName = sourceURL.lastPathComponent
        } else {
            baseName = defaultFilename(suffix: "file")
        }

        return appendFileExtensionIfNeeded(filename: baseName, typeIdentifier: typeIdentifier, defaultExtension: nil)
    }
}
