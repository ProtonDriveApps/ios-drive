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

extension Thumbnail {
    enum Error: Swift.Error {
        case noFileMeta
        case blockDataNotDownloaded
        case blockIsNotReadyForMoving
        case noEncryptedSignatureOrEmail
        case tamperedThumbnail
        case invalidMetadata
        case noSignatureAddress
    }

    public var clearThumbnail: Data? {
        if let clear = clearData {
            return clear
        }

        guard encrypted != nil else { return nil }

        do {
            let sessionKey = try revision.decryptContentSessionKey()
            let decrypted = try decrypt(sessionKey: sessionKey)
            self.clearData = decrypted
            return decrypted
        } catch {
            self.clearData = Data()
            return clearData
        }
    }

    internal func decrypt(sessionKey: Data, decryptionResource: DecryptionResource = Decryptor()) throws -> Data {
        do {
            guard let thumbnailDataPacket = encrypted else {
                throw Error.blockDataNotDownloaded
            }

            if let thumbnailHash = sha256,
               thumbnailHash != Decryptor.hashSha256(thumbnailDataPacket) {
                throw Error.tamperedThumbnail
            }

            do {
                let decryptedData = try decryptionResource.decryptBlock(thumbnailDataPacket, sessionKey: sessionKey)
                
                self.clearData = decryptedData
                return decryptedData
            } catch let error where !(error is Decryptor.Errors) {
                DriveIntegrityErrorMonitor.reportContentError(for: revision.file)
                throw error
            }
        } catch {
            Log.error(error: DecryptionError(error, "Thumbnail", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nVolumeID: \(revision.file.volumeID)"), domain: .encryption)
            throw error
        }
    }

    #if os(iOS)
    public static func saveClearDataToDisk(
        clearData: Data,
        type: ThumbnailType,
        identifier: NodeIdentifier,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        completion: (() -> Void)? = nil
    ) {
        DispatchQueue.global().async {
            let storageType = preferredStorageType(identifier: identifier)
            let url = PDFileManager.createThumbnailURL(for: identifier, type: type, storageType: storageType)
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(atPath: url.path)
                }
                try clearData.write(to: url)
            } catch {
                let parent = url.deletingLastPathComponent()
                let hasParent = FileManager.default.fileExists(atPath: parent.path)
                Log.error("Save clear data to disk failed, has parent? \(hasParent)", error: error, domain: .photosUI, file: file, function: function, line: line)
            }
            completion?()
        }
    }

    public static func saveClearDataToDisk(
        clearData: Data,
        type: ThumbnailType,
        identifier: NodeIdentifier
    ) async {
        await withCheckedContinuation { continuation in
            saveClearDataToDisk(
                clearData: clearData,
                type: type,
                identifier: identifier,
                completion: {
                    continuation.resume()
                }
            )
        }
    }
    
    private static func preferredStorageType(identifier: NodeIdentifier) -> FileStorageType {
        let permanentURL = PDFileManager
            .fileURL(for: identifier, prefix: nil, storageType: .permanent, shouldCreate: false)
        if FileManager.default.fileExists(atPath: permanentURL.path) { return .permanent }
        return .temporary
    }
    #endif // os(iOS)
}
