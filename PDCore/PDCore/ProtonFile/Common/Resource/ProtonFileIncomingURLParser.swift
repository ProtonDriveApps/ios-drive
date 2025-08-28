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

protocol ProtonFileIncomingURLParserProtocol {
    func parse(_ url: URL) throws -> NodeIdentifier
}

final class ProtonFileIncomingURLParser: ProtonFileIncomingURLParserProtocol {
    private static let availableSuffixes = [
        "." + ProtonDocConstants.fileExtension,
        "." + ProtonSheetConstants.fileExtension
    ]

    func parse(_ url: URL) throws -> NodeIdentifier {
        let components = url.pathComponents
        let componentsCount = components.count
        guard componentsCount > 3 else {
            Log.warning("Trying to open invalid url: \(url)", domain: .protonDocs)
            throw ProtonFileOpeningError.invalidIncomingURL
        }
        let lastComponent = components[componentsCount - 1]
        guard ProtonFileIncomingURLParser.availableSuffixes.contains(where: { lastComponent.hasSuffix($0) }) else {
            Log.warning("Trying to open invalid url: \(url)", domain: .protonDocs)
            throw ProtonFileOpeningError.invalidIncomingFileExtension
        }
        let nodeId = components[componentsCount - 2]
        let shareId = components[componentsCount - 3]
        // VolumeID not defined on this endpoint at the moment
        return NodeIdentifier(nodeId, shareId, "")
    }
}
