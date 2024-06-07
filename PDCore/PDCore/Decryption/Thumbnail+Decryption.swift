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

    internal func decrypt(sessionKey: Data) throws -> Data {
        do {
            guard let thumbnailDataPacket = encrypted else {
                throw Error.blockDataNotDownloaded
            }

            if let thumbnailHash = sha256,
               thumbnailHash != Decryptor.hashSha256(thumbnailDataPacket) {
                throw Error.tamperedThumbnail
            }

            let addressKeys = try revision.getAddressPublicKeysOfRevisionCreator()
            let decrypted = try Decryptor.decryptAndVerifyThumbnail(
                thumbnailDataPacket,
                contentSessionKey: sessionKey,
                verificationKeys: addressKeys
            )

            switch decrypted {
            case .verified(let thumbnail):
                self.clearData = thumbnail
                return thumbnail

            case .unverified(let thumbnail, let error):
                Log.error(SignatureError(error, "Thumbnail Passphrase", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nShareID: \(revision.file.shareID)"), domain: .encryption)
                self.clearData = thumbnail
                return thumbnail
            }

        } catch {
            Log.error(DecryptionError(error, "Thumbnail", description: "RevisionID: \(revision.id) \nLinkID: \(revision.file.id) \nShareID: \(revision.file.shareID)"), domain: .encryption)
            throw error
        }
    }

}
