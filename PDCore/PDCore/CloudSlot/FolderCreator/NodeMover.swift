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

import Foundation
import PDClient
import CoreData

public protocol NodeMoverProtocol {
    func move(_ node: Node, to newParent: Folder, name: String) async throws
    func move(photo: CoreDataPhoto, from album: CoreDataAlbum, to photoRoot: Folder) async throws
}

public final class NodeMover: NodeMoverProtocol {
    /// Typealias for one of the methods of PDClient's Client.
    public typealias CloudNodeMover = (Client.ShareID, Client.LinkID, MoveEntryEndpoint.Parameters) async throws -> Void

    private let moc: NSManagedObjectContext
    private let storage: StorageManager
    private let signersKitFactory: SignersKitFactoryProtocol
    private let cloudNodeMover: CloudNodeMover

    public init(
        storage: StorageManager,
        cloudNodeMover: @escaping CloudNodeMover,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.moc = moc
        self.storage = storage
        self.signersKitFactory = signersKitFactory
        self.cloudNodeMover = cloudNodeMover
    }
    
    public func move(_ node: Node, to newParent: Folder, name: String) async throws {
        let validatedNewName = try name.validateNodeName(validator: NameValidations.iosName)
        let cryptoInfo = try await readCryptoInfo(from: node, and: newParent)
        
        let parameters = try prepareRequestParameter(
            node: node,
            cryptoInfo: cryptoInfo,
            validatedNewName: validatedNewName
        )
        
        try await cloudNodeMover(cryptoInfo.shareID, cryptoInfo.nodeID, parameters)

        try await moc.perform {
            let node = node.in(moc: self.moc)
            let newParent = newParent.in(moc: self.moc)

            node.name = parameters.Name
            node.nodeHash = parameters.Hash
            node.nodePassphrase = parameters.NodePassphrase
            if cryptoInfo.isAnonymous {
                if let signature = parameters.NodePassphraseSignature {
                    node.nodePassphraseSignature = signature
                }
                node.nameSignatureEmail = cryptoInfo.signersKit.address.email
                node.signatureEmail = cryptoInfo.signersKit.address.email
            }

            node.parentFolder = newParent

            try self.moc.saveOrRollback()
        }
    }

    public func move(photo: CoreDataPhoto, from album: CoreDataAlbum, to photoRoot: Folder) async throws {
        let name = try await self.moc.perform { try photo.decryptName() }
        let validatedNewName = try name.validateNodeName(validator: NameValidations.iosName)
        let cryptoInfo = try await readCryptoInfo(from: photo, album: album, and: photoRoot)

        let parameters = try prepareRequestParameter(
            node: photo,
            cryptoInfo: cryptoInfo,
            validatedNewName: validatedNewName
        )

        try await cloudNodeMover(cryptoInfo.shareID, cryptoInfo.nodeID, parameters)

        try await moc.perform {
            let node = photo.in(moc: self.moc)
            let newParent = photoRoot.in(moc: self.moc)

            node.name = parameters.Name
            node.nodeHash = parameters.Hash
            node.nodePassphrase = parameters.NodePassphrase
            if cryptoInfo.isAnonymous {
                if let signature = parameters.NodePassphraseSignature {
                    node.nodePassphraseSignature = signature
                }
                node.nameSignatureEmail = cryptoInfo.signersKit.address.email
                node.signatureEmail = cryptoInfo.signersKit.address.email
            }

            node.parentFolder = newParent

            try self.moc.saveOrRollback()
        }
    }

    private func readCryptoInfo(
        from node: Node,
        album: CoreDataAlbum? = nil,
        and newParent: Folder
    ) async throws -> CryptoInfo {
        try await moc.perform {
            let node = node.in(moc: self.moc)
#if os(macOS)
            let signersKit = try self.signersKitFactory.make(forSigner: .main)
#else
            let addressID = try node.getContextShareAddressID()
            let signersKit = try self.signersKitFactory.make(forAddressID: addressID)
#endif
            let newParent = newParent.in(moc: self.moc)
            guard let oldParent = album ?? node.parentFolder else {
                throw node.invalidState("The moving Node should have a parent.")
            }
            guard let oldNodeName = node.name else {
                throw node.invalidState("The renaming Node should have a valid old name.")
            }
            return .init(
                isAnonymous: node.signatureEmail?.isEmpty ?? true,
                nodeID: node.id,
                shareID: try node.getContextShare().id,
                oldNodeName: oldNodeName,
                oldNodePassphrase: node.nodePassphrase,
                oldDecryptedNodePassphrase: try node.decryptNodePassphrase().decrypted(),
                oldNodeNameSignatureEmail: node.nameSignatureEmail,
                oldNodeSignatureEmail: node.signatureEmail,
                oldNameHash: node.nodeHash,
                oldParentKey: oldParent.nodeKey,
                oldParentPassphrase: try oldParent.decryptPassphrase(),
                newParentKey: newParent.nodeKey,
                newParentHashKey: try newParent.decryptNodeHashKey(),
                newParentNodeID: newParent.id,
                signersKit: signersKit,
                contentDigest: try self.getContentDigest(for: node)
            )
        }
    }

    private func getContentDigest(for node: Node) throws -> FileContentDigest? {
        // Only needed for photos
        if let photo = node as? CoreDataPhoto {
            return try photo.photoRevision.getContentDigest()
        } else {
            return nil
        }
    }

    private func prepareRequestParameter(
        node: Node,
        cryptoInfo: CryptoInfo,
        validatedNewName: String
    ) throws -> MoveEntryEndpoint.Parameters {
        if cryptoInfo.isAnonymous {
            return try prepareRequestParameterForAnonymous(
                node: node,
                cryptoInfo: cryptoInfo,
                validatedNewName: validatedNewName
            )
        } else {
            return try prepareRequestParameterForNormal(
                node: node, 
                cryptoInfo: cryptoInfo,
                validatedNewName: validatedNewName
            )
        }
    }
    
    private func prepareRequestParameterForAnonymous(
        node: Node,
        cryptoInfo: CryptoInfo,
        validatedNewName: String
    ) throws -> MoveEntryEndpoint.Parameters {
        let newEncryptedName = try node.encryptName(
            cleartext: validatedNewName,
            parentKey: cryptoInfo.newParentKey,
            signersKit: cryptoInfo.signersKit
        )
        let newNameHash = try Encryptor.hmac(filename: validatedNewName, parentHashKey: cryptoInfo.newParentHashKey)
        
        let updatedCredential = try Encryptor.updateNodeKeys(
            passphraseString: cryptoInfo.oldDecryptedNodePassphrase,
            addressPassphrase: cryptoInfo.signersKit.addressPassphrase,
            addressPrivateKey: cryptoInfo.signersKit.addressKey.privateKey,
            parentKey: cryptoInfo.newParentKey
        )

        let isNameSignatureEmailEmpty = cryptoInfo.oldNodeNameSignatureEmail?.isEmpty ?? true
        let isSignatureEmailEmpty = cryptoInfo.oldNodeSignatureEmail?.isEmpty ?? true
        var nodePassphraseSignature: String?
        var signatureEmail: String?
        if isNameSignatureEmailEmpty && isSignatureEmailEmpty {
            signatureEmail = cryptoInfo.signersKit.address.email
            nodePassphraseSignature = updatedCredential.signature
        } else if isSignatureEmailEmpty {
            signatureEmail = cryptoInfo.signersKit.address.email
            nodePassphraseSignature = updatedCredential.signature
        }

        return MoveEntryEndpoint.Parameters(
            name: newEncryptedName,
            nodePassphrase: updatedCredential.nodePassphrase,
            hash: newNameHash,
            parentLinkID: cryptoInfo.newParentNodeID,
            nameSignatureEmail: cryptoInfo.signersKit.address.email,
            originalHash: cryptoInfo.oldNameHash,
            newShareID: nil,
            nodePassphraseSignature: nodePassphraseSignature,
            signatureEmail: signatureEmail,
            contentHash: try makeContentHash(info: cryptoInfo)
        )
    }

    private func prepareRequestParameterForNormal(
        node: Node,
        cryptoInfo: CryptoInfo,
        validatedNewName: String
    ) throws -> MoveEntryEndpoint.Parameters {
        let newNodePassphrase = try node.reencryptNodePassphrase(
            oldNodePassphrase: cryptoInfo.oldNodePassphrase,
            oldParentKey: cryptoInfo.oldParentKey,
            oldParentPassphrase: cryptoInfo.oldParentPassphrase,
            newParentKey: cryptoInfo.newParentKey
        )
        let newEncryptedName = try node.renameNode(
            oldEncryptedName: cryptoInfo.oldNodeName,
            oldParentKey: cryptoInfo.oldParentKey,
            oldParentPassphrase: cryptoInfo.oldParentPassphrase,
            newClearName: validatedNewName,
            newParentKey: cryptoInfo.newParentKey,
            signersKit: cryptoInfo.signersKit
        )
        let newNameHash = try Encryptor.hmac(filename: validatedNewName, parentHashKey: cryptoInfo.newParentHashKey)

        return MoveEntryEndpoint.Parameters(
            name: newEncryptedName,
            nodePassphrase: newNodePassphrase,
            hash: newNameHash,
            parentLinkID: cryptoInfo.newParentNodeID,
            nameSignatureEmail: cryptoInfo.signersKit.address.email,
            originalHash: cryptoInfo.oldNameHash,
            newShareID: nil,
            contentHash: try makeContentHash(info: cryptoInfo)
        )
    }

    private func makeContentHash(info: CryptoInfo) throws -> String? {
        switch info.contentDigest {
        case let .contentDigest(digest):
            return try Encryptor().makeHmac(string: digest, hashKey: info.newParentHashKey)
        case let .contentHash(previousContentHash):
            // We fall back to using the previous content hash in cases there's no original decrypted one.
            // It doesn't prevent duplicates per se, but works for repeated move action.
            return previousContentHash
        case nil:
            // Nil is valid for non-photo objects
            return nil
        }
    }
}

extension NodeMover {
    private struct CryptoInfo {
        let isAnonymous: Bool
        let nodeID: String
        let shareID: String
        let oldNodeName: String
        let oldNodePassphrase: String
        let oldDecryptedNodePassphrase: String
        let oldNodeNameSignatureEmail: String?
        let oldNodeSignatureEmail: String?
        let oldNameHash: String
        let oldParentKey: String
        let oldParentPassphrase: String
        let newParentKey: String
        let newParentHashKey: String
        let newParentNodeID: String
        let signersKit: SignersKit
        let contentDigest: FileContentDigest?
    }
}
