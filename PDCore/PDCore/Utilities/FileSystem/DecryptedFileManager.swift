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

/// iOS' only implementation of revision decrypted file storage
#if os(iOS)
public class DecryptedFileManager {

    // MARK: - Validation

    /// Path points to existing decrypted data, and may refer to either a temporary or permanent location
    public static func validatedDecryptedFilePath(identifier: NodeIdentifier) -> URL? {
        validateTemporaryClearFilePath(identifier: identifier) ??
        validatePermanentClearFilePath(identifier: identifier) ??
        validateFileProviderClearPath(identifier: identifier)
    }

    /// Path points to existing temporary decrypted data
    /// - Returns: Returns the path if the file already exists
    public static func validateTemporaryClearFilePath(identifier: NodeIdentifier) -> URL? {
        let tempPath = temporaryClearURL(identifier: identifier, shouldCreate: false)
        if FileManager.default.fileExists(atPath: tempPath.path(percentEncoded: false)) {
            return tempPath
        }
        return nil
    }

    /// Path points to existing permanent decrypted data
    /// - Returns: Returns the path if the file already exists
    public static func validatePermanentClearFilePath(identifier: NodeIdentifier) -> URL? {
        let permanentPath = permanentClearURL(identifier: identifier, shouldCreate: false)
        if FileManager.default.fileExists(atPath: permanentPath.path(percentEncoded: false)) {
            return permanentPath
        }
        return nil
    }

    public static func validateFileProviderClearPath(identifier: NodeIdentifier) -> URL? {
        if let path = fileProviderClearURL(identifier: identifier),
           FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) {
            return path
        }
        return nil
    }

    // MARK: - Paths generation

    /// Construct path to temporary directory for normal file storage
    /// - Parameter shouldCreate: iOS only. Should create the folder if it doesn't exist
    public static func temporaryClearURL(identifier: NodeIdentifier, shouldCreate: Bool) -> URL {
        PDFileManager.fileURL(for: identifier, prefix: nil, storageType: .temporary, shouldCreate: shouldCreate)
    }

    /// Construct path to permanent directory, for file available offline
    /// - Parameter shouldCreate: iOS only. Should create the folder if it doesn't exist
    public static func permanentClearURL(identifier: NodeIdentifier, shouldCreate: Bool) -> URL {
        PDFileManager.fileURL(for: identifier, prefix: nil, storageType: .permanent, shouldCreate: shouldCreate)
    }

    public static func fileProviderClearURL(identifier: NodeIdentifier) -> URL? {
        PDFileManager.decryptedDataURLForFileInFP(identifier: identifier)
    }
}
#endif // os(iOS)
