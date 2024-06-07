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

public final class NodeMover {
    /// Typealias for one of the methods of PDCLient's Client.
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
        let signersKit = try signersKitFactory.make(forSigner: .main)
        let validatedNewName = try name.validateNodeName(validator: NameValidations.iosName)

        let (nodeID, shareID, oldNodeName, oldNodePassphrase, oldNameHash, oldParentKey, oldParentPassphrase, newParentKey, newParentHashKey, newParentNodeID) = try await moc.perform {
            let node = node.in(moc: self.moc)
            let newParent = newParent.in(moc: self.moc)
            guard let oldParent = node.parentLink else { throw node.invalidState("The moving Node should have a parent.") }

            let nodeID = node.id
            let shareID = node.shareID
            guard let oldNodeName = node.name else { throw node.invalidState("The renaming Node should have a valid old name.") }
            let oldNodePassphrase = node.nodePassphrase
            let oldNameHash = node.nodeHash

            let oldParentKey = oldParent.nodeKey
            let oldParentPassphrase = try oldParent.decryptPassphrase()

            let newParentKey = newParent.nodeKey
            let newParentHashKey = try newParent.decryptNodeHashKey()

            return (nodeID, shareID, oldNodeName, oldNodePassphrase, oldNameHash, oldParentKey, oldParentPassphrase, newParentKey, newParentHashKey, newParent.id)
        }

        let newNodePassphrase = try node.reencryptNodePassphrase(
            oldNodePassphrase: oldNodePassphrase,
            oldParentKey: oldParentKey,
            oldParentPassphrase: oldParentPassphrase,
            newParentKey: newParentKey
        )
        let newEncryptedName = try node.renameNode(
            oldEncryptedName: oldNodeName,
            oldParentKey: oldParentKey,
            oldParentPassphrase: oldParentPassphrase,
            newClearName: validatedNewName,
            newParentKey: newParentKey,
            signersKit: signersKit
        )
        let newNameHash = try Encryptor.hmac(filename: validatedNewName, parentHashKey: newParentHashKey)

        let parameters = MoveEntryEndpoint.Parameters(
            name: newEncryptedName,
            nodePassphrase: newNodePassphrase,
            hash: newNameHash,
            parentLinkID: newParentNodeID,
            nameSignatureEmail: signersKit.address.email,
            originalHash: oldNameHash,
            newShareID: nil
        )

        try await cloudNodeMover(shareID, nodeID, parameters)

        try await moc.perform {
            let node = node.in(moc: self.moc)
            let newParent = newParent.in(moc: self.moc)

            node.name = newEncryptedName
            node.nodeHash = newNameHash
            node.nodePassphrase = newNodePassphrase

            node.parentLink = newParent

            try self.moc.saveOrRollback()
        }
    }
}
