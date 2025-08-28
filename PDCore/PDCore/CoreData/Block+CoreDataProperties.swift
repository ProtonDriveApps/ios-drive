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
import CoreData

extension Block: VolumeUnique {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Block> {
        return NSFetchRequest<Block>(entityName: "Block")
    }

    @NSManaged public var id: String
    @NSManaged public var volumeID: String
    @NSManaged var localPath: String? // this should be relative path, relative to some BaseURL
    @NSManaged public var index: Int
    @NSManaged public var sha256: Data
    @NSManaged public var revision: Revision
    @NSManaged public var encSignature: String?
    @NSManaged public var signatureEmail: String?
    
    public var localUrl: URL? {
        guard self.localPath != nil else { return nil }
        if FileManager.default.fileExists(atPath: self.temporaryUrl!.path) {
            return self.temporaryUrl
        }
        if FileManager.default.fileExists(atPath: self.permanentUrl!.path) {
            return self.permanentUrl
        }
        return nil
    }
    
    fileprivate var temporaryUrl: URL? {
        guard let path = self.localPath else { return nil }
        return PDFileManager.cypherBlocksCacheDirectory.appendingPathComponent(path)
    }
    
    fileprivate var permanentUrl: URL? {
        guard let path = self.localPath else { return nil }
        return PDFileManager.cypherBlocksPermanentDirectory.appendingPathComponent(path)
    }
    
    func move(to newBase: Downloader.DownloadLocation) throws {
        switch newBase {
        case .offlineAvailable:
            if let localUrl, let permanentUrl {
                try FileManager.default.moveItem(at: localUrl, to: permanentUrl)
            }
        case .temporary:
            if let localUrl, let temporaryUrl, permanentUrl != nil {
                try FileManager.default.moveItem(at: localUrl, to: temporaryUrl)
            }
        case .oblivion:
            if let localUrl {
                try FileManager.default.removeItem(at: localUrl)
            }
        }
    }
}

extension DownloadBlock {
    func store(cypherfileFrom intermediateUrl: URL) throws -> URL {
        let blockFilename = UUID().uuidString
        self.localPath = blockFilename
        
        let localUrl = self.temporaryUrl!
        try FileManager.default.copyItem(at: intermediateUrl, to: localUrl)
        
        do {
            try self.managedObjectContext?.saveOrRollback()
        } catch let error {
            assert(false, error.localizedDescription)
            throw error
        }
        
        return localUrl
    }
    
    func createEmptyFile() throws {
        let blockFilename = UUID().uuidString
        self.localPath = blockFilename

        let localUrl = self.temporaryUrl!
        FileManager.default.createFile(atPath: localUrl.path, contents: nil, attributes: nil)

        do {
            try self.managedObjectContext?.saveOrRollback()
        } catch let error {
            assert(false, error.localizedDescription)
            throw error
        }
    }
}

extension UploadBlock {
    func store(cyphertext: Data) throws -> URL {
        let blockFilename = UUID().uuidString
        self.localPath = blockFilename
        
        let localUrl = self.temporaryUrl!
        try cyphertext.write(to: localUrl)
        
        return localUrl
    }
    
    func store(cyphertext: URL) throws -> URL {
        let blockFilename = UUID().uuidString
        self.localPath = blockFilename
        
        let localUrl = self.temporaryUrl!
        try FileManager.default.moveItem(at: cyphertext, to: localUrl)
        
        return localUrl
    }
}
