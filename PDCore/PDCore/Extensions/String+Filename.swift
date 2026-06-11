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
        return replacingOccurrences(of: "/", with: "_")
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
    
    /// Masks the basename of a filename while preserving its extension.
    ///
    /// The masking rules are:
    /// - If the basename length is greater than 2:
    ///   Keeps the first and last character, and replaces the middle characters
    ///   with `{n}`, where `n` is the number of removed characters.
    ///   - Example: `"abcd.jpg"` → `"a{2}d.jpg"`
    ///
    /// - If the basename length is 2 or fewer:
    ///   Masks the entire basename as `{n}`, where `n` is the length of the basename.
    ///   - Example: `"ab.jpg"` → `"{2}.jpg"`
    ///   - Example: `"a.jpg"` → `"{1}.jpg"`
    ///
    /// - If the filename has no extension, the same rules apply to the full string.
    ///   - Example: `"abc"` → `"a{1}c"`
    ///
    /// - The file extension (including the dot) is preserved unchanged.
    ///
    /// - Parameter filename: The original filename (e.g., `"example.png"`).
    /// - Returns: A masked filename string following the rules above.
    func maskFilename() -> String {
        let filename = self
        // Find last dot for extension
        let dotIndex = filename.lastIndex(of: ".")
        
        let name: String
        let ext: String
        
        if let dot = dotIndex {
            name = String(filename[..<dot])
            ext = String(filename[dot...])
        } else {
            name = filename
            ext = ""
        }
        
        let length = name.count
        
        // If too short, mask entire name
        if length <= 2 {
            return "{\(length)}\(ext)"
        }
        
        // Normal masking
        let first = name.first!
        let last = name.last!
        let hiddenCount = length - 2
        
        return "\(first){\(hiddenCount)}\(last)\(ext)"
    }
}
