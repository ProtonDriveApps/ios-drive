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

public final class NodeRenamer {
    /// Typealias for one of the methods of PDCLient's Client.
    public typealias CloudNodeRenamer = (Client.ShareID, Client.LinkID, RenameNodeParameters) async throws -> Void

    private let moc: NSManagedObjectContext
    private let storage: StorageManager
    private let signersKitFactory: SignersKitFactoryProtocol
    private let cloudNodeRenamer: CloudNodeRenamer

    public init(
        storage: StorageManager,
        cloudNodeRenamer: @escaping CloudNodeRenamer,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.moc = moc
        self.storage = storage
        self.signersKitFactory = signersKitFactory
        self.cloudNodeRenamer = cloudNodeRenamer
    }

    public func rename(_ node: Node, to newName: String, mimeType: String?) async throws {
        let signersKit = try signersKitFactory.make(forSigner: .main)
        let validatedNewName = try newName.validateNodeName(validator: NameValidations.iosName)

        let (nodeID, shareID, oldNodeName, parentKey, parentPassphrase, parentHashKey) = try await moc.perform {
            let node = node.in(moc: self.moc)
            let nodeID = node.id
            let shareID = node.shareID

            guard let oldNodeName = node.name else { throw node.invalidState("The renaming Node should have a valid old name.") }

            guard let parent = node.parentLink else { throw node.invalidState("The renaming Node should have a parent.") }
            let parentKey = parent.nodeKey
            let parentPassphrase = try parent.decryptPassphrase()
            let parentHashKey = try parent.decryptNodeHashKey()

            return (nodeID, shareID, oldNodeName, parentKey, parentPassphrase, parentHashKey)
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
            signatureAddress: signersKit.address.email
        )

        try await cloudNodeRenamer(shareID, nodeID, parameters)

        try await moc.perform {
            let node = node.in(moc: self.moc)
            node.name = newEncryptedName
            node.nodeHash = newNameHash

            // MIME type should remain unchanged if the rename either removed
            // the file extension, or it's Proton Doc, which doesn't have an
            // extension on other platform.
            if let mimeType {
                node.mimeType = mimeType
            }

            try self.moc.saveOrRollback()
        }
    }
}
