// Copyright (c) 2024 Proton AG
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

import ProtonCoreCrypto

import Foundation
import CoreData

@objc(CoreDataBookmark)
public class CoreDataBookmark: File {
    @NSManaged public var locallyEncryptedName: String
    @NSManaged public var encryptedUrlPassword: String
    @NSManaged public var token: String
    @NSManaged public var sharePasswordSalt: String
    @NSManaged public var sharePassphrase: String
    @NSManaged public var shareKey: String
    @NSManaged public var permissions: Int16

    override public func decryptName() throws -> String {
        if !Constants.runningInExtension {
            // Looks like file providers do no exchange updates across contexts properly
            if let cached = self.clearName {
                return cached
            }

            // Node can be a fault on in the file providers at this point
            guard !isFault else { return Self.unknownNamePlaceholder }
        }
        Log.info("decryptName bookmark: \(id)", domain: .storage)
        let name = locallyEncryptedName
        self.clearName = name
        return name
    }

    public func decryptPassword() throws -> String {
        let keys = try getAddressKeys()
        return try Decryptor.decrypt(decryptionKeys: keys, value: encryptedUrlPassword)
    }

    public func decryptPGPName(withPassword password: String) throws -> String {
        do {
            guard let name else { throw DriveError("No name found in Bookmark") }
            let computedPassword = try Decryptor.computeKeyPassword(password: password, salt: sharePasswordSalt)
            let sharePassphrase = try ProtonCoreCrypto.Decryptor.decrypt(encrypted: ProtonCoreCrypto.ArmoredMessage.init(value: sharePassphrase), token: TokenPassword.init(value: computedPassword))
            let shareDecryptionKey = DecryptionKey(privateKey: shareKey, passphrase: sharePassphrase)
            let decryptedName = try Decryptor.decryptAttachedTextMessage(name, decryptionKeys: [shareDecryptionKey])
            nameDecryptionFailed = false
            self.clearName = decryptedName
            return decryptedName
        } catch {
            throw error
        }
    }

    func getAddressKeys() throws -> [DecryptionKey] {
        guard let addresses = SessionVault.current.addresses else {
            throw DriveError("Invalid state, no available addresses")
        }

        return addresses
            .flatMap(\.activeKeys)
            .compactMap(KeyPair.init)
            .map(\.decryptionKey)
    }
}

public extension CoreDataBookmark {
    static func makeBookmark(_ bookmark: Bookmark, in context: NSManagedObjectContext) -> CoreDataBookmark {
        let identifier = BookmarkIdentifier(id: bookmark.token.linkID)
        let coredataBookmark = CoreDataBookmark.fetchOrCreate(identifier: identifier, in: context)
        coredataBookmark.encryptedUrlPassword = bookmark.encryptedUrlPassword
        coredataBookmark.createdDate = bookmark.createTime
        coredataBookmark.token = bookmark.token.token
        coredataBookmark.sharePasswordSalt = bookmark.token.sharePasswordSalt
        coredataBookmark.sharePassphrase = bookmark.token.sharePassphrase
        coredataBookmark.shareKey = bookmark.token.shareKey
        coredataBookmark.nodePassphrase = bookmark.token.nodePassphrase
        coredataBookmark.nodeKey = bookmark.token.nodeKey
        coredataBookmark.name = bookmark.token.name
        coredataBookmark.contentKeyPacket = bookmark.token.contentKeyPacket
        coredataBookmark.mimeType = bookmark.token.mimeType
        coredataBookmark.permissions = Int16(bookmark.token.permissions)
        coredataBookmark.size = bookmark.token.size
        coredataBookmark.isSharedWithMeRoot = true
        coredataBookmark.state = .active

        coredataBookmark.nodeHash = "bookmark"
        coredataBookmark.nodePassphraseSignature = "bookmark"
        coredataBookmark.shareID = "bookmark"

        return coredataBookmark
    }
}
