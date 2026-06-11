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

/// Remove cached files from permanent, temporary, and File Provider storage
public struct NodeTreeCacheFileRemover: NodeTreeCacheFileRemoverProtocol {

    public init() {}

    public func perform(to nodes: [Node]) {
        let (files, folders, photos) = cast(nodes: nodes)
        files.forEach { deleteCached(file: $0) }
        photos.forEach { deleteCached(file: $0) }
        folders.forEach { deleteCached(folder: $0) }
    }

    private func deleteCached(file: CoreDataFile) {
#if os(iOS)
        let identifier = file.identifierWithinManagedObjectContext
        Task.detached {
            let tempURL = PDFileManager
                .prepareTempV1URLForFile(identifier: identifier, shouldCreate: false, prefix: nil)
                .deletingLastPathComponent()
            try? FileManager.default.removeItem(at: tempURL)
            
            let permanentURL = PDFileManager
                .preparePermanentV1URLForFile(identifier: identifier, shouldCreate: false)
                .deletingLastPathComponent()
            try? FileManager.default.removeItem(at: permanentURL)
            
            let fpURL = PDFileManager
                .decryptedDataV1URLForFileInFP(identifier: identifier)?
                .deletingLastPathComponent()
            fpURL.map { try? FileManager.default.removeItem(at: $0) }
            
            for type in FileStorageType.allCases {
                let url = PDFileManager.fileFolder(for: identifier, storageType: type, shouldCreate: false)
                try? FileManager.default.removeItem(at: url)
            }
            let fpURLV2 = PDFileManager
                .decryptedDataURLForFileInFP(identifier: identifier)?
                .deletingLastPathComponent()
            fpURLV2.map { try? FileManager.default.removeItem(at: $0) }
        }
#endif
    }

    private func deleteCached(folder: CoreDataFolder) {
        let (childFiles, childFolders) = children(from: folder)
        childFiles.forEach { deleteCached(file: $0) }
        childFolders.forEach { deleteCached(folder: $0) }
    }
}
