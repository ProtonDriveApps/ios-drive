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

/// Provides access to commonly used directories
/// Stateful, needs to be configured with App Group directory before usage by calling ``PDFileManager/configure(with:)``  with a correct settings suite.
/// If not configured, all URLs will be placed in a default temporary directory of current process
public final class PDFileManager {
    static var appGroupUrl: URL = FileManager.default.temporaryDirectory

    /// Defines state of manager with a settings suite because some URLs are located in App Groups directory
    public static func configure(with suite: SettingsStorageSuite) {
        self.appGroupUrl = suite.directoryUrl

        initializeIntermediateFolders()
    }

    /// Creates all intermediate folders if they do not exist
    public static func initializeIntermediateFolders() {
        _ = cleartextCacheDirectory
        _ = cypherBlocksCacheDirectory
        _ = cypherBlocksPermanentDirectory
    }

    /// Removes parent directories of data considered disposable
    public static func destroyCaches() {
        try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil).forEach { childURL in
            try? FileManager.default.removeItem(at: childURL)
        }
        try? FileManager.default.removeItem(at: appGroupTemporaryDirectory)
    }

    /// Removes file provider caches
    public static func destroyFPCaches() {
        #if os(iOS)
        let url = NSFileProviderManager.default.documentStorageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        #endif
    }

    /// Removes data explicitly marked as important for local access - Offline Available, etc
    public static func destroyPermanents() {
        try? FileManager.default.removeItem(at: cypherBlocksPermanentDirectory)
    }

    /// Creates a random subfolder under cleartext cache directory, returns new URL with requested last component
    public static func prepareUrlForFile(named filename: String) -> URL {
        #if os(macOS)
        let filename = filename.filenameSanitizedForFilesystem()
        #endif
        var url = self.cleartextCacheDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.createIfNeeded(&url)
        return url.appendingPathComponent(filename)
    }

    /// Directory for caching cleartext. Placed in temporary directory of current process in order to benefit from OS-driven periodic cleanups to protect "forgotten" cleartext files
    public static var cleartextCacheDirectory: URL {
        var temp = FileManager.default.temporaryDirectory.appendingPathComponent("Clear")
        self.createIfNeeded(&temp)
        return temp
    }

    /// Directory for caching cleartext bug report attachments. Placed in temporary directory of current process in order to benefit from OS-driven periodic cleanups to protect "forgotten" cleartext files
    public static var bugReportAttachmentsDirectory: URL {
        var temp = cleartextCacheDirectory.appendingPathComponent("BugReportAttachments")
        self.createIfNeeded(&temp)
        return temp
    }

    /// Directory for caching cleartext Photos. Placed in temporary directory of current process in order to benefit from OS-driven periodic cleanups to protect "forgotten" cleartext files
    public static var cleartextPhotosCacheDirectory: URL {
        var temp = cleartextCacheDirectory.appendingPathComponent("Photos")
        self.createIfNeeded(&temp)
        return temp
    }

    /// Creates a random subfolder under cleartext photos cache directory, returns new URL with requested last component
    public static func prepareUrlForPhotoFile(named filename: String) -> URL {
        var url = self.cleartextPhotosCacheDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.createIfNeeded(&url)
        return url.appendingPathComponent(filename)
    }

    /// Directory for caching cleartext. Placed in App Groups directory because encrypted data can be safely stored for a long time
    public static var cypherBlocksCacheDirectory: URL {
        var temp = self.appGroupTemporaryDirectory.appendingPathComponent("Downloads")
        self.createIfNeeded(&temp)
        return temp
    }

    /// Directory for data explicitly marked as important for local access - Offilne Available, etc
    public static var cypherBlocksPermanentDirectory: URL {
        var temp = self.appGroupUrl.appendingPathComponent("Downloads")
        self.createIfNeeded(&temp)
        return temp
    }

    /// Directory for disposable data in App Group directory
    public static var appGroupTemporaryDirectory: URL {
        var temp = self.appGroupUrl.appendingPathComponent("tmp")
        self.createIfNeeded(&temp)
        return temp
    }

    /// Creates a directory with intermediates if they do not exist, applies security flags
    public static func createIfNeeded(_ url: inout URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.secureFilesystemItems(url)
            } catch let error {
                assert(false, error.localizedDescription)
            }
        }
    }

    static func ensureDirectoryExists(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.secureFilesystemItems(url)
        }
    }

    static func copyMetadata(stage: String) {
        let sqlite = appGroupUrl.appendingPathComponent("Metadata.sqlite")
        let sqlite_shm = appGroupUrl.appendingPathComponent("Metadata.sqlite-shm")
        let sqlite_wal = appGroupUrl.appendingPathComponent("Metadata.sqlite-wal")

        var destination = FileManager.default.temporaryDirectory.appendingPathComponent("DB").appendingPathComponent(stage)
        self.createIfNeeded(&destination)
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

    // MARK: Logs

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

    public static func copyDatabases(from source: URL, to destination: URL) throws {
        #if INCLUDES_DB_IN_BUGREPORT
        // Metadata
        let metadata_sqlite = source.appendingPathComponent("Metadata.sqlite")
        let metadata_sqlite_shm = source.appendingPathComponent("Metadata.sqlite-shm")
        let metadata_sqlite_wal = source.appendingPathComponent("Metadata.sqlite-wal")

        // Events
        let events_sqlite = source.appendingPathComponent("EventStorageModel.sqlite")
        let events_sqlite_shm = source.appendingPathComponent("EventStorageModel.sqlite-shm")
        let events_sqlite_wal = source.appendingPathComponent("EventStorageModel.sqlite-wal")

        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        }

        try? FileManager.default.removeItem(at: destination.appendingPathComponent("Metadata.sqlite"))
        try? FileManager.default.removeItem(at: destination.appendingPathComponent("Metadata.sqlite-shm"))
        try? FileManager.default.removeItem(at: destination.appendingPathComponent("Metadata.sqlite-wal"))

        try? FileManager.default.removeItem(at: destination.appendingPathComponent("EventStorageModel.sqlite"))
        try? FileManager.default.removeItem(at: destination.appendingPathComponent("EventStorageModel.sqlite-shm"))
        try? FileManager.default.removeItem(at: destination.appendingPathComponent("EventStorageModel.sqlite-wal"))

        try FileManager.default.copyItem(at: metadata_sqlite, to: destination.appendingPathComponent("Metadata.sqlite"))
        try FileManager.default.copyItem(at: metadata_sqlite_shm, to: destination.appendingPathComponent("Metadata.sqlite-shm"))
        try FileManager.default.copyItem(at: metadata_sqlite_wal, to: destination.appendingPathComponent("Metadata.sqlite-wal"))

        try FileManager.default.copyItem(at: events_sqlite, to: destination.appendingPathComponent("EventStorageModel.sqlite"))
        try FileManager.default.copyItem(at: events_sqlite_shm, to: destination.appendingPathComponent("EventStorageModel.sqlite-shm"))
        try FileManager.default.copyItem(at: events_sqlite_wal, to: destination.appendingPathComponent("EventStorageModel.sqlite-wal"))
        #endif
    }

    static func getLastTwoPathComponents(from url: URL) -> String? {
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 2 else { return nil }

        let lastTwoComponents = pathComponents.suffix(2)
        return lastTwoComponents.joined(separator: "/")
    }
}
