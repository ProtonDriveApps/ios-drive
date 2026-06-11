// Copyright (c) 2023 Proton AG
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
import FileProvider
import ProtonCoreCrypto

/// Provides access to commonly used directories
/// Stateful, needs to be configured with App Group directory before usage by calling ``PDFileManager/configure(with:)``  with a correct settings suite.
/// If not configured, all URLs will be placed in a default temporary directory of current process
public final class PDFileManager {
    static var appGroupUrl: URL = FileManager.default.temporaryDirectory
    private static let createQueue = DispatchQueue(label: "com.proton.drive.filemanager.create", qos: .utility)
    
    /// Directory for disposable data in App Group directory
    public static var appGroupTemporaryDirectory: URL {
        let temp = self.appGroupUrl.appendingPathComponent("tmp")
        self.createIfNeeded(temp)
        return temp
    }
    
    /// Directory for caching cleartext. Placed in temporary directory of current process in order to benefit from OS-driven periodic cleanups to protect "forgotten" cleartext files
    public static var cleartextCacheDirectory: URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("Clear")
        self.createIfNeeded(temp)
        return temp
    }
    
    /// Directory for data explicitly marked as important for local access - Offline Available, etc
    public static var permanentDataDirectory: URL {
        let temp = self.appGroupUrl.appendingPathComponent("Downloads")
        self.createIfNeeded(temp)
        return temp
    }
    
    /// Directory for caching cleartext. Placed in App Groups directory because encrypted data can be safely stored for a long time
    /// Used for both download blocks (prefix `Download-`) and upload blocks
    public static var cypherBlocksCacheDirectory: URL {
        let temp = self.appGroupTemporaryDirectory.appendingPathComponent("Downloads")
        self.createIfNeeded(temp)
        return temp
    }
}

extension PDFileManager {
    /// Defines state of manager with a settings suite because some URLs are located in App Groups directory
    public static func configure(with suite: SettingsStorageSuite) {
        self.appGroupUrl = suite.directoryUrl

        initializeIntermediateFolders()
    }
    
    /// Removes parent directories of data considered disposable
    public static func destroyCaches() {
        try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil).forEach { childURL in
            try? FileManager.default.removeItem(at: childURL)
        }
        try? FileManager.default.removeItem(at: appGroupTemporaryDirectory)
    }
    
    /// Removes data explicitly marked as important for local access - Offline Available, etc
    public static func destroyPermanents() {
        try? FileManager.default.removeItem(at: permanentDataDirectory)
    }
    
    static func ensureDirectoryExists(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { return }
        try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.secureFilesystemItems(url)
    }
    
    /// Creates all intermediate folders if they do not exist
    public static func initializeIntermediateFolders() {
        _ = cleartextCacheDirectory
        _ = cypherBlocksCacheDirectory
        _ = permanentDataDirectory
    }
    
    /// Creates a directory with intermediates if they do not exist, applies security flags
    public static func createIfNeeded(_ url: URL) {
        // Fast check without queue
        if FileManager.default.fileExists(atPath: url.path) { return }

        createQueue.sync {
            for retry in 1...3 {
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    try FileManager.default.secureFilesystemItems(url)
                    break
                } catch let error {
                    Log.warning("Failed to create directory: \(url.path), retry: \(retry), error: \(error.localizedDescription)", domain: .storage)
                    Thread.sleep(forTimeInterval: 0.3)
                    if retry == 3 {
                        Log.error("Failed to create directory: \(url.path), retry: \(retry)", error: error, domain: .storage)
                        assert(false, error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // To dump database for testing
    static func copyMetadata(stage: String) {
        let sqlite = appGroupUrl.appendingPathComponent("Metadata.sqlite")
        let sqlite_shm = appGroupUrl.appendingPathComponent("Metadata.sqlite-shm")
        let sqlite_wal = appGroupUrl.appendingPathComponent("Metadata.sqlite-wal")
        
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("DB").appendingPathComponent(stage)
        self.createIfNeeded(destination)
        let sqlite_copy = destination.appendingPathComponent("\(stage).sqlite")
        let sqlite_shm_copy = destination.appendingPathComponent("\(stage).sqlite-shm")
        let sqlite_wal_copy = destination.appendingPathComponent("\(stage).sqlite-wal")
        
        try? FileManager.default.copyItem(at: sqlite, to: sqlite_copy)
        try? FileManager.default.copyItem(at: sqlite_shm, to: sqlite_shm_copy)
        try? FileManager.default.copyItem(at: sqlite_wal, to: sqlite_wal_copy)
        
        let mainKey = try? SessionVault.current.mainKeyProvider.mainKeyOrError
        dump("Recorder 🔴: key 🔑 - \(Data(mainKey!).base64EncodedString()) ")
        dump("Recorder 🔴: stage 📁 - \(destination.absoluteURL)")
    }
}

// MARK: - Logs
extension PDFileManager {
    public static func getLogsDirectory() throws -> URL {
        guard let appGroupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup) else {
            throw PDFileManagerError.noLogDirectory
        }
        return appGroupDirectory.appendingPathComponent("Logs", isDirectory: true)
    }
    
    /// Dumps given string into a log file.
    /// Will overwrite the file if it's present.
    public static func dumpLogs(_ logs: String, toFile filename: String, in directory: URL) throws {
        let logPath = directory.appendingPathComponent(filename, isDirectory: false)
        try? logs.write(to: logPath, atomically: false, encoding: .utf8)
    }
    
    public static func appendLogs(_ logs: String, toFile filename: String, in directory: URL) throws {
        let logPath = directory.appendingPathComponent(filename, isDirectory: false)
        if let fileHandle = FileHandle(forWritingAtPath: logPath.path) {
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            
            if let data = logs.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
        } else {
            try logs.write(to: logPath, atomically: false, encoding: .utf8)
        }
    }
    
    public static func appendFileContents(from sourceURL: URL, to destinationURL: URL) throws {
        do {
            let sourceContent = try String(contentsOf: sourceURL, encoding: .utf8)
            try appendString(string: sourceContent, to: destinationURL)
        } catch {
            throw error
        }
    }
    
    public static func appendString(string: String, to destinationURL: URL) throws {
        do {
            if let fileHandle = FileHandle(forWritingAtPath: destinationURL.path) {
                defer { try? fileHandle.close() }
                try fileHandle.seekToEnd()
                if let data = string.data(using: .utf8) {
                    try fileHandle.write(contentsOf: data)
                }
            } else {
                try string.write(to: destinationURL, atomically: false, encoding: .utf8)
            }
        } catch {
            throw error
        }
    }
}
