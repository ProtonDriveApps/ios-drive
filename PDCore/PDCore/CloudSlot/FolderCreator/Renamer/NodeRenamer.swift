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

import PDClient
import CoreData

public final class NodeRenamer: NodeRenamerProtocol {
    /// Typealias for one of the methods of PDCLient's Client.
    public typealias CloudNodeRenamer = (Client.ShareID, Client.LinkID, RenameNodeParameters) async throws -> Void

    private let signersKitFactory: SignersKitFactoryProtocol
    private let cloudNodeRenamer: CloudNodeRenamer
    private let metadataRefresher: NodeMetadataRefreshing?

    public init(
        cloudNodeRenamer: @escaping CloudNodeRenamer,
        signersKitFactory: SignersKitFactoryProtocol,
        metadataRefresher: NodeMetadataRefreshing? = nil
    ) {
        self.signersKitFactory = signersKitFactory
        self.cloudNodeRenamer = cloudNodeRenamer
        self.metadataRefresher = metadataRefresher
    }

    public func rename(_ node: Node, to newName: String, mimeType: String?, moc: NSManagedObjectContext) async throws {
        let validatedNewName = try newName.validateNodeName(validator: NameValidations.iosName)
        try await performWithOutOfSyncRetry(
            node: node,
            moc: moc,
            metadataRefresher: metadataRefresher,
            attempt: { try await self.attemptRename(node, to: validatedNewName, mimeType: mimeType, moc: moc) },
            stillNeeded: { try await self.renameStillNeeded(node, to: validatedNewName, moc: moc) }
        )
    }

    private func attemptRename(_ node: Node, to validatedNewName: String, mimeType: String?, moc: NSManagedObjectContext) async throws {
        let nodeManagedObjectID = node.objectID
        
        let (nodeID, shareID, oldNodeName, currentNodeHash, parentKey, parentPassphrase, parentHashKey, signersKit) = try await moc.perform {
            let node = moc.object(with: nodeManagedObjectID) as! Node
            let nodeID = node.id
            let shareID = try node.getContextShare().id
#if os(macOS)
            let signersKit = try node.getContextShareAddressBasedSignersKit(signersKitFactory: self.signersKitFactory,
                                                                            fallbackSigner: .main)
#else
            let signersKit = try node.getContextShareAddressBasedSignersKit(signersKitFactory: self.signersKitFactory)
#endif
            guard let oldNodeName = node.name else { throw node.invalidState("The renaming Node should have a valid old name.") }

            guard let parent = node.parentNode else { throw node.invalidState("The renaming Node should have a parent.") }
            let parentKey = parent.nodeKey
            let parentPassphrase = try parent.decryptPassphrase()
            let parentHashKey = try parent.decryptNodeHashKey()

            return (nodeID, shareID, oldNodeName, node.nodeHash, parentKey, parentPassphrase, parentHashKey, signersKit)
        }

        let newEncryptedName = try node.renameNode(
            oldEncryptedName: oldNodeName,
            oldParentKey: parentKey,
            oldParentPassphrase: parentPassphrase,
            newClearName: validatedNewName,
            newParentKey: parentKey,
            signersKit: signersKit
        )
        let newNameHash = try Encryptor.hmac(filename: validatedNewName, parentHashKey: parentHashKey)
        let parameters = RenameNodeParameters(
            name: newEncryptedName,
            hash: newNameHash,
            MIMEType: mimeType,
            signatureAddress: signersKit.address.email,
            originalHash: currentNodeHash
        )
        
        let nameSignatureEmail = signersKit.address.email

        try await cloudNodeRenamer(shareID, nodeID, parameters)

        try await moc.perform {
            let node = moc.object(with: nodeManagedObjectID) as! Node
            node.name = newEncryptedName
            node.nodeHash = newNameHash
            node.nameSignatureEmail = nameSignatureEmail

            // MIME type should remain unchanged if the rename either removed
            // the file extension, or it's Proton Doc, which doesn't have an
            // extension on other platform.
            if let mimeType {
                node.mimeType = mimeType
            }

            try moc.saveOrRollback()
        }
    }

    private func renameStillNeeded(_ node: Node, to validatedNewName: String, moc: NSManagedObjectContext) async throws -> Bool {
        let nodeManagedObjectID = node.objectID
        return try await moc.perform {
            guard let node = moc.object(with: nodeManagedObjectID) as? Node else { return false }
            guard let parent = node.parentNode else {
                throw node.invalidState("The renaming Node should have a parent.")
            }
            let target = try Encryptor.hmac(filename: validatedNewName, parentHashKey: parent.decryptNodeHashKey())
            return node.nodeHash != target
        }
    }
}
