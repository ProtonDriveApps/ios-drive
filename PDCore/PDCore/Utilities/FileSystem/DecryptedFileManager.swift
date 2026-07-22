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
import Darwin

public enum DecryptedFileManagerError: Error, Equatable {
    case noDecryptedFile
}

#if os(iOS)
public final class LegacyDecryptionCancellation: @unchecked Sendable {
    public var isCancelled = false

    public init() {}
}

/// iOS' only implementation of revision decrypted file storage
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

    public static func decryptLegacyBlocksIfNeeded(
        file: File,
        cancellation: LegacyDecryptionCancellation? = nil
    ) async throws {
        guard let moc = file.moc else { throw File.noMOC() }
        let objectID = file.objectID
        try await moc.perform {
            let file: File = try moc.typedObject(with: objectID)
            guard let revision = file.activeRevision else {
                throw file.invalidState("Uploaded file should have an active revision")
            }
            if revision.blocksAreValid() {
                if let cancellation {
                    _ = try revision.decryptFile(isCancelled: &cancellation.isCancelled)
                } else {
                    _ = try revision.decryptFile()
                }
            }
        }
    }
}

// MARK: - Hard links
extension DecryptedFileManager {
    // The decrypted file is stored at `{UserID}/{encoded_prefix}/{encoded_suffix}/file`
    // Create a hard link that points to this location
    // so the preview view and share sheet can display the correct file name
    //
    // In Finder, you will see two files: `file` and `{name}.{ext}`
    // The folder size will appear doubled because Finder simply sums the size of each entry
    // However, both files reference the same inode, so no data is actually duplicated
    // You can run `ls -li path_to_folder` to confirm that they point to the same inode
    // And `du -h path_to_folder` to see actual disk usage
    public static func ensureHardLink(identifier: AnyVolumeIdentifier, filename: String) throws -> URL {
        try ensureHardLink(identifier: identifier.volumeBasedIdentifier, filename: filename)
    }

    public static func ensureHardLink(identifier: NodeIdentifier, filename: String) throws -> URL {
        guard let realURL = validatedDecryptedFilePath(identifier: identifier) else {
            throw DecryptedFileManagerError.noDecryptedFile
        }
        let hardLinkURL = realURL.deletingLastPathComponent().appending(path: filename)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: hardLinkURL.path(percentEncoded: false)) {
            if fileResourceIdentifiersMatch(hardLinkURL, realURL) {
                return hardLinkURL
            }
            try fileManager.removeItem(at: hardLinkURL)
        }

        do {
            try fileManager.linkItem(at: realURL, to: hardLinkURL)
        } catch {
            if fileManager.fileExists(atPath: hardLinkURL.path(percentEncoded: false)),
               fileResourceIdentifiersMatch(hardLinkURL, realURL) {
                return hardLinkURL
            }
            throw error
        }
        return hardLinkURL
    }

    static func fileResourceIdentifiersMatch(_ lhs: URL, _ rhs: URL) -> Bool {
        var lhsStat = stat()
        var rhsStat = stat()
        let lhsPath = lhs.path(percentEncoded: false)
        let rhsPath = rhs.path(percentEncoded: false)
        guard stat(lhsPath, &lhsStat) == 0, stat(rhsPath, &rhsStat) == 0 else { return false }
        return lhsStat.st_ino == rhsStat.st_ino && lhsStat.st_dev == rhsStat.st_dev
    }
}
#endif // os(iOS)
