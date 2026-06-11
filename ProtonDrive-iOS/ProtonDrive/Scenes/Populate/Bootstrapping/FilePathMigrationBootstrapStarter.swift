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
import PDCore
import PDCoreIOS

// To relocate file and thumbnail to v2 path
// Check document `File storage strategy` for more details about /{encoded_prefix}/{encoded_suffix}
final class FilePathMigrationBootstrapStarter: AppBootstrapper {
    
    func bootstrap() async throws {
        try measure(message: "Relocate files and thumbnails", domain: .applicationBootstrap) {
            PDFileManager.clearIncompleteDownloads()
            
            // Relocate file first so we know thumbnail should be relocated to where
            for type in FileStorageType.allCases {
                try relocateFiles(storageType: type)
            }
            
            try relocateThumbnails()
        }
    }
    
    /// Relocate thumbnail file from V1 path to V2 path
    /// V1 path: `tmp/thumbnail/{UserID}/{VolumeID}/{NodeID}/default.dec (or photo.dec)`
    /// V2 path: `tmp/{UserID}/{encoded_prefix}/{encoded_suffix}/thumbnail (or thumbnail_photo)`
    private func relocateThumbnails() throws {
        let legacyThumbnailDirectory = userStorageRoot(for: PDFileManager.thumbnailDirectory)
        guard FileManager.default.fileExists(atPath: legacyThumbnailDirectory.path) else { return }
        let legacyVolumeDirectories = try children(of: legacyThumbnailDirectory)
        for volumeURL in legacyVolumeDirectories {
            let volumeID = volumeURL.lastPathComponent
            let nodeURLs = try children(of: volumeURL)
            for nodeURL in nodeURLs {
                let nodeID = nodeURL.lastPathComponent
                let id = AnyVolumeIdentifier(id: nodeID, volumeID: volumeID)
                let storageType = try storageType(of: id)
                for thumbnailType in ThumbnailType.allCases {
                    let legacyURL = PDFileManager.clearThumbnailV1URL(
                        for: id.volumeBasedIdentifier,
                        type: thumbnailType,
                        shouldCreate: false
                    )
                    guard FileManager.default.fileExists(atPath: legacyURL.path) else { continue }
                    let thumbnailURL = PDFileManager.createThumbnailURL(
                        for: id.volumeBasedIdentifier,
                        type: thumbnailType,
                        storageType: storageType
                    )
                    try FileManager.default.moveItem(at: legacyURL, to: thumbnailURL)
                }
            }
            try FileManager.default.removeItem(at: volumeURL)
        }
        try FileManager.default.removeItem(at: legacyThumbnailDirectory)
    }
    
    /// Relocate cached file from V1 path to V2 path
    /// V1 path:
    ///   - `tmp/{UserID}/{VolumeID}/{NodeID}/clear`
    ///   - `Downloads/{UserID}/{VolumeID}/{NodeID}/clear`
    /// V2 path: `tmp/{UserID}/{encoded_prefix}/{encoded_suffix}/file`
    private func relocateFiles(storageType: FileStorageType) throws {
        let userDirectory = storageType.directory.appending(path: PDFileManager.getUserID())
        guard FileManager.default.fileExists(atPath: userDirectory.path) else { return }
        let legacyVolumeDirectories = try children(of: userDirectory)
        for volumeURL in legacyVolumeDirectories {
            let volumeID = volumeURL.lastPathComponent
            let nodeURLs = try children(of: volumeURL)
            for nodeURL in nodeURLs {
                let legacyFileURL = nodeURL.appendingPathComponent(PDFileManager.clearFilename)
                guard FileManager.default.fileExists(atPath: legacyFileURL.path) else { continue }
                let id = AnyVolumeIdentifier(id: nodeURL.lastPathComponent, volumeID: volumeID)
                let fileURL = PDFileManager.fileURL(
                    for: id.volumeBasedIdentifier,
                    prefix: nil,
                    storageType: storageType,
                    shouldCreate: true
                )
                try FileManager.default.moveItem(at: legacyFileURL, to: fileURL)
            }
            try FileManager.default.removeItem(at: volumeURL)
        }
    }
}

extension FilePathMigrationBootstrapStarter {
    private func userStorageRoot(for root: URL) -> URL {
        let userID = PDFileManager.getUserID()
        return root.appendingPathComponent(userID)
    }
    
    private func children(of root: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: []
        )
        return contents.filter { url in
            if url.lastPathComponent == ".DS_Store" { return false }
            // V2 folder
            if url.lastPathComponent.count == 2 { return false }
            return true
        }
    }
    
    private func storageType(of id: AnyVolumeIdentifier) throws -> FileStorageType {
        for type in FileStorageType.allCases {
            let url = PDFileManager.fileFolder(for: id.volumeBasedIdentifier, storageType: type, shouldCreate: false)
            if FileManager.default.fileExists(atPath: url.path), !(try children(of: url)).isEmpty {
                return type
            }
        }
        return .temporary
    }
}
