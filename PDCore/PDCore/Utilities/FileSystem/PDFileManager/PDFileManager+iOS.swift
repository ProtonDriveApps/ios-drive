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

#if os(iOS)
import Foundation
import FileProvider

// MARK: - Static variables
extension PDFileManager {
    private static var currentUserID: String?
    public static let clearFilename = "clear"
    static let clearFilenameV2 = "file"
    /// Temporary folder to store files from share extension
    static let shareTempFolderName = "shareTemp"
    
    /// Directory for caching cleartext bug report attachments. Placed in temporary directory of current process in order to benefit from OS-driven periodic cleanups to protect "forgotten" cleartext files
    public static var bugReportAttachmentsDirectory: URL {
        let temp = cleartextCacheDirectory.appendingPathComponent("BugReportAttachments")
        self.createIfNeeded(temp)
        return temp
    }
    
    /// Directory for caching cleartext Photos. Placed in temporary directory of current process in order to benefit from OS-driven periodic cleanups to protect "forgotten" cleartext files
    public static var cleartextPhotosCacheDirectory: URL {
        let temp = cleartextCacheDirectory.appendingPathComponent("Photos")
        self.createIfNeeded(temp)
        return temp
    }
    
    public static var shareTempFolderDirectory: URL {
        let path = appGroupTemporaryDirectory.appendingPathComponent(shareTempFolderName)
        createIfNeeded(path)
        return path
    }
    
    public static var sdkDownloadsDirectory: URL {
        let path = appGroupTemporaryDirectory.appendingPathComponent("sdk_downloads")
        self.createIfNeeded(path)
        return path
    }
}

extension PDFileManager {
    public static func getUserID() -> String {
        if currentUserID == nil && !Constants.isUITest && !Constants.isUnitTest {
            // Prevent test crashes caused by missing userID
            assertionFailure("currentUserID is nil")
        }
        return currentUserID ?? "unknown"
    }
    
    public static func set(userID: String) {
        currentUserID = userID
    }

    /// Removes file provider caches
    public static func destroyFPCaches() {
        guard
            let url = getFileProviderStorageURL(),
            FileManager.default.fileExists(atPath: url.path)
        else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    public static func clearIncompleteDownloads() {
        DispatchQueue.global().async {
            // We don't support download resumption, remove incomplete download files to free disk
            let legacyDownloadPath = cypherBlocksCacheDirectory
            if let contents = try? FileManager.default.contentsOfDirectory(at: legacyDownloadPath, includingPropertiesForKeys: nil) {
                for itemURL in contents where itemURL.lastPathComponent.hasPrefix("Download-") {
                    try? FileManager.default.removeItem(at: itemURL)
                }
            }
            
            try? FileManager.default.removeItem(at: sdkDownloadsDirectory)
        }
    }
}

extension PDFileManager {
    public static func getFileProviderStorageURL() -> URL? {
        // `documentStorageURL` crashes when FP is not installed
        guard Constants.buildFeatures.hasFileProvider else { return nil }
        return NSFileProviderManager.default.documentStorageURL
    }
    
    /// Creates a random subfolder under cleartext photos cache directory, returns new URL with requested last component
    public static func prepareUrlForPhotoFile(named filename: String, folderName: String? = nil) -> URL {
        let folderName = folderName ?? UUID().uuidString
        let url = cleartextPhotosCacheDirectory.appendingPathComponent(folderName, isDirectory: true)
        createIfNeeded(url)
        return url.appendingPathComponent(filename)
    }
    
    /// Creates a random subfolder under cleartext cache directory, returns new URL with requested last component
    public static func prepareUrlForFile(named filename: String) -> URL {
        let url = cleartextCacheDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        createIfNeeded(url)
        return url.appendingPathComponent(filename)
    }
}

extension PDFileManager {
    /// Generate encoded path from given identifier
    /// Changed from private to internal for testing purposes
    /// - Returns: "{UserID}/{encoded_prefix}/{encoded_suffix}"
    static func encodedPath(from identifier: NodeIdentifier, pathPrefix: String? = nil) -> String {
        let uid = "\(identifier.volumeID)~\(identifier.nodeID)"
        let encoded = Data(uid.utf8).sha256().base64URLEncodedString().lowercased()
        let start = encoded.startIndex
        let end = encoded.index(start, offsetBy: 2)
        let prefix = encoded[start..<end]
        let suffix = encoded[end...]
        let path = "\(getUserID())/\(prefix)/\(suffix)"
        if let pathPrefix {
            return "\(pathPrefix)/\(path)"
        }
        return path
    }
    
    public static func createThumbnailURL(
        for identifier: NodeIdentifier,
        type: ThumbnailType,
        storageType: FileStorageType
    ) -> URL {
        let name = type == .default ? "thumbnail" : "thumbnail_photo"
        let url = fileFolder(for: identifier, storageType: storageType, shouldCreate: true)
        return url.appendingPathComponent(name)
    }
    
    /// Returns the URL for a node's thumbnail in temporary or permanent storage.
    ///
    /// If `preferStorageType` is set, returns the URL in that storage only if the file exists.
    /// If not set, prefers the temporary thumbnail when it exists; otherwise falls back to permanent.
    /// The thumbnail file name is "thumbnail" for `.default` and "thumbnail_photo" otherwise.
    ///
    /// - Parameters:
    ///   - identifier: The node identifier.
    ///   - type: The thumbnail type.
    ///   - preferStorageType: Optional preferred storage to check first.
    /// - Returns: The existing thumbnail URL, or `nil` if none is found.
    public static func thumbnailURL(
        for identifier: NodeIdentifier,
        type: ThumbnailType,
        preferStorageType: FileStorageType? = nil
    ) -> URL? {
        let name = type == .default ? "thumbnail" : "thumbnail_photo"
        if let preferStorageType {
            let url = fileFolder(for: identifier, storageType: preferStorageType, shouldCreate: false)
                .appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        
        let tempPath = fileFolder(for: identifier, storageType: .temporary, shouldCreate: false)
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: tempPath.path) { return tempPath }
        
        let permanentPath = fileFolder(for: identifier, storageType: .permanent, shouldCreate: false)
            .appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: permanentPath.path) ? permanentPath : nil
    }
    
    public static func fileURL(
        for identifier: NodeIdentifier,
        prefix: String?,
        storageType: FileStorageType,
        shouldCreate: Bool
    ) -> URL {
        let url = fileFolder(for: identifier, storageType: storageType, prefix: prefix, shouldCreate: shouldCreate)
        return url.appendingPathComponent(clearFilenameV2)
    }
    
    public static func fileFolder(
        for identifier: NodeIdentifier,
        storageType: FileStorageType,
        prefix: String? = nil,
        shouldCreate: Bool
    ) -> URL {
        let path = encodedPath(from: identifier, pathPrefix: prefix)
        let url = storageType.directory.appendingPathComponent(path, isDirectory: true)
        if shouldCreate {
            createIfNeeded(url)
        }
        return url
    }
    
    public static func decryptedDataURLForFileInFP(identifier: NodeIdentifier) -> URL? {
        if Constants.isUnitTest {
            return appGroupTemporaryDirectory.appendingPathComponent("unittest", isDirectory: true)
        }
        
        guard var url = getFileProviderStorageURL() else { return nil }
        url.appendPathComponent(encodedPath(from: identifier), isDirectory: true)
        url.appendPathComponent(clearFilenameV2, isDirectory: false)
        return url
    }
}

// MARK: - Share extension
extension PDFileManager {
    public static func prepareShareTempURL(for filename: String) -> URL {
        shareTempFolderDirectory.appendingPathComponent(filename)
    }
    
    public static func cleanShareTempFolder() {
        do {
            try FileManager.default.removeItem(at: shareTempFolderDirectory)
        } catch {
            Log.error("", error: error, domain: .storage)
        }
    }
}

// MARK: - Deprecated
extension PDFileManager {
    public static var thumbnailDirectory: URL {
        let path = appGroupTemporaryDirectory.appendingPathComponent("thumbnail")
        createIfNeeded(path)
        return path
    }
    
    /// Construct a clear data path that stores files in the app group’s temporary directory.
    public static func prepareTempV1URLForFile(
        identifier: NodeIdentifier,
        shouldCreate: Bool,
        prefix: String?
    ) -> URL {
        var path = "\(getUserID())/\(identifier.volumeID)/\(identifier.nodeID)"
        if let prefix {
            path = "\(prefix)/" + path
        }
        let url = self.appGroupTemporaryDirectory.appendingPathComponent(path, isDirectory: true)
        if shouldCreate {
            self.createIfNeeded(url)
        }
        return url.appendingPathComponent(clearFilename)
    }
    
    /// Construct a clear data path that stores files in the app group’s directory.
    public static func preparePermanentV1URLForFile(
        identifier: NodeIdentifier,
        shouldCreate: Bool
    ) -> URL {
        let path = "\(getUserID())/\(identifier.volumeID)/\(identifier.nodeID)"
        let url = permanentDataDirectory.appendingPathComponent(path, isDirectory: true)
        if shouldCreate {
            createIfNeeded(url)
        }
        return url.appendingPathComponent(clearFilename)
    }
    
    /// Legacy thumbnail store location, `{VolumeID}/{NodeID}/default.dec`
    /// The problem is this need to create a lots of folder
    /// But sometimes `createIfNeeded` neither creates folder nor throw error
    public static func clearThumbnailV1URL(
        for identifier: NodeIdentifier,
        type: ThumbnailType,
        shouldCreate: Bool
    ) -> URL {
        let name = type == .default ? "default.dec" : "photo.dec"
        let path = "\(getUserID())/\(identifier.volumeID)/\(identifier.nodeID)"
        let url = thumbnailDirectory.appendingPathComponent(path, isDirectory: true)
        if shouldCreate {
            createIfNeeded(url)
        }
        return url.appendingPathComponent(name)
    }
    
    public static func decryptedDataV1URLForFileInFP(identifier: NodeIdentifier) -> URL? {
        if Constants.isUnitTest {
            let url = appGroupTemporaryDirectory.appendingPathComponent("unittest", isDirectory: true)
            return url
        }
        
        guard var url = getFileProviderStorageURL() else { return nil }
        
        url.appendPathComponent(getUserID(), isDirectory: true)
        url.appendPathComponent(identifier.volumeID, isDirectory: true)
        url.appendPathComponent(identifier.nodeID, isDirectory: true)
        url.appendPathComponent(clearFilename, isDirectory: false)
        return url
    }
}

public enum FileStorageType: CaseIterable {
    case temporary
    case permanent
    
    public var directory: URL {
        switch self {
        case .temporary:
            return PDFileManager.appGroupTemporaryDirectory
        case .permanent:
            return PDFileManager.permanentDataDirectory
        }
    }
}
#endif
