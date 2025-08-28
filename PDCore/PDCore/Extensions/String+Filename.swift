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

public extension String {

    var nameExcludingExtension: String {
        URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }

    func filenameSanitizedForFilesystem() -> String {
        return self.replacing(#/[/]/#, with: "_")
    }

    func appendingProtonExtensionIfNecessary(basedOn mimeType: String) -> String {
        switch mimeType {
        case ProtonDocConstants.mimeType:
            return self.appendingExtension(ProtonDocConstants.fileExtension)
        case ProtonSheetConstants.mimeType:
            return self.appendingExtension(ProtonSheetConstants.fileExtension)
        default:
            return self
        }
    }

    private func appendingExtension(_ pathExtension: String) -> String {
        // Shouldn't convert to URL, because `appendingPathExtension` fails for
        // paths containing `:` chars
        let suffixWithDot = "." + pathExtension
        guard !self.hasSuffix(suffixWithDot) else { return self }

        return self + suffixWithDot
    }

    func removingProtonExtensionIfNecessary() -> String {
        switch self.fileExtension {
        case ProtonDocConstants.fileExtension:
            return self.nameExcludingExtension
        case ProtonSheetConstants.fileExtension:
            return self.nameExcludingExtension
        default:
            return self
        }
    }
}
