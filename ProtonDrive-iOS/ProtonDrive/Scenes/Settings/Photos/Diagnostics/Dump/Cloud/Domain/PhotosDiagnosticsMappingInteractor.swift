// Copyright (c) 2024 Proton AG
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

final class PhotosDiagnosticsMappingInteractor {
    private let decryptorFactory: CloudDecryptorFactory

    init(decryptorFactory: CloudDecryptorFactory) {
        self.decryptorFactory = decryptorFactory
    }

    func map(response: PhotosDiagnosticsResponse) throws -> [Tree.Node] {
        // Initialize decryptor with photos share
        Log.debug("Initializing decryption", domain: .diagnostics)
        let decryptor = try decryptorFactory.makeAttributesDecryptor(share: response.share)
        
        // Fill root decryption keys
        try decryptor.buildDecryptionData(response.root)

        // Group photos by iCloud identifier
        Log.debug("Grouping photos by their iCloud identifier", domain: .diagnostics)
        let dictionary = try buildIdKeydPhotoDictionary(response: response, decryptor: decryptor)

        // Each identifier will represent a single node with photos as children
        Log.debug("Building tree nodes", domain: .diagnostics)
        return try dictionary.map { identifier, photos in
            try self.makeNode(identifier: identifier, photos: photos, decryptor: decryptor)
        }
    }

    private func buildIdKeydPhotoDictionary(response: PhotosDiagnosticsResponse, decryptor: CloudAttributesDecryptor) throws -> [String: [PhotosDiagnosticsResponse.Photo]] {
        var dictionary = [String: [PhotosDiagnosticsResponse.Photo]]()
        try response.photos.forEach { photo in
            let extendedAttributes = try decryptor.decryptExtendedAttributes(photo.primary)
            let iCloudId = extendedAttributes.iOSPhotos?.iCloudID
            if iCloudId == nil {
                Log.warning("Extended attributes don't contain iCloudID. This might be because a photo has been uploaded using different client.", domain: .diagnostics)
            }
            // We don't interrupt the diagnostics in case of a missing iCloudID. Either it signifies an issue and will be reflected when matching diagnostics
            // or it's a photo uploaded using different client.
            let identifier = iCloudId ?? "Missing iCloudID"
            dictionary[identifier] = (dictionary[identifier] ?? []) + [photo]
        }
        return dictionary
    }

    private func makeNode(identifier: String, photos: [PhotosDiagnosticsResponse.Photo], decryptor: CloudNodeDecryptor) throws -> Tree.Node {
        return Tree.Node(
            title: identifier,
            descendants: try photos.map { try makePhotoNode(from: $0, decryptor: decryptor) }
        )
    }

    private func makePhotoNode(from photo: PhotosDiagnosticsResponse.Photo, decryptor: CloudNodeDecryptor) throws -> Tree.Node {
        let decryptedName = try decryptor.decryptName(photo.primary)
        let descendants = try photo.secondary.map { link in
            try decryptor.decryptName(link)
        }
        return Tree.Node(title: decryptedName, descendants: descendants)
    }
}
