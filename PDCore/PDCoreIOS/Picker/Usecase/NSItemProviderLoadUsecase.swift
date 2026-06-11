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
import UniformTypeIdentifiers

protocol NSItemProviderLoadUsecase {
    func appendFileExtensionIfNeeded(filename: String, typeIdentifier: String, defaultExtension: String?) -> String
    func appendFileExtensionIfNeeded(filename: String, utType: UTType?, defaultExtension: String?) -> String
    func defaultFilename(suffix: String) -> String
}

extension NSItemProviderLoadUsecase {
    func appendFileExtensionIfNeeded(filename: String, typeIdentifier: String, defaultExtension: String?) -> String {
        appendFileExtensionIfNeeded(filename: filename, utType: UTType(typeIdentifier), defaultExtension: defaultExtension)
    }

    func appendFileExtensionIfNeeded(filename: String, utType: UTType?, defaultExtension: String?) -> String {
        let originalType = UTType(filenameExtension: filename.fileExtension)
        // filename has correct file extension, doesn't need to be updated
        if originalType == utType { return filename }

        guard let preferredExtension = utType?.preferredFilenameExtension ?? defaultExtension else { return filename }
        let suffix = ".\(preferredExtension)"
        if filename.lowercased().hasSuffix(suffix.lowercased()) {
            return filename
        }
        return "\(filename).\(preferredExtension)"
    }

    func defaultFilename(suffix: String) -> String {
        "shared-\(suffix)-\(Date.formattedNow("yyyy-MM-dd HH:mm:ss.SSS"))"
    }
}
