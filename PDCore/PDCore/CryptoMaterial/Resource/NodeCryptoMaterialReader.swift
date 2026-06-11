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

import CoreData
import Foundation

public protocol NodeCryptoMaterialReaderProtocol {
    func readNode(identifier: AnyVolumeIdentifier) async throws -> NodeCryptoMaterial
    func readNode(identifier: AnyVolumeIdentifier) throws -> NodeCryptoMaterial
    func readNodeWithHashKey(identifier: AnyVolumeIdentifier) async throws -> NodeParentCryptoMaterial
}

public struct NodeCryptoMaterialReader: NodeCryptoMaterialReaderProtocol {
    private let moc: NSManagedObjectContext
    private let signersKitFactory: SignersKitFactoryProtocol

    public init(
        moc: NSManagedObjectContext,
        signersKitFactory: SignersKitFactoryProtocol
    ) {
        self.moc = moc
        self.signersKitFactory = signersKitFactory
    }

    public func readNode(identifier: AnyVolumeIdentifier) async throws -> NodeCryptoMaterial {
        try await moc.perform {
            try readNode(identifier: identifier)
        }
    }

    /// Use when you already in NSManagedObjectContext
    public func readNode(identifier: AnyVolumeIdentifier) throws -> NodeCryptoMaterial {
        let node: Node = try Node.fetchOrThrow(identifier: identifier, allowSubclasses: true, in: self.moc)
#if os(macOS)
        let signersKit = try node.getContextShareAddressBasedSignersKit(signersKitFactory: self.signersKitFactory,
                                                                        fallbackSigner: .main)
#else
        let signersKit = try node.getContextShareAddressBasedSignersKit(signersKitFactory: self.signersKitFactory)
#endif

        // For photo, reads parentNode
        // For node, reads parentFolder
        guard let oldParent = node.parentNode else {
            throw node.invalidState("The moving Node should have a parent.")
        }
        guard let oldNodeName = node.name else {
            throw node.invalidState("The renaming Node should have a valid old name.")
        }
        return NodeCryptoMaterial(
            isAnonymous: node.signatureEmail?.isEmpty ?? true,
            id: identifier.any(),
            oldNodeName: oldNodeName,
            oldDecryptedNodeName: try node.decryptName(),
            oldNodePassphrase: node.nodePassphrase,
            oldDecryptedNodePassphrase: try node.decryptNodePassphrase().decrypted(),
            oldNodeNameSignatureEmail: node.nameSignatureEmail,
            oldNodeSignatureEmail: node.signatureEmail,
            oldNameHash: node.nodeHash,
            oldParentKey: oldParent.nodeKey,
            oldParentPassphrase: try oldParent.decryptPassphrase(),
            signersKit: signersKit,
            contentDigest: try self.getContentDigest(for: node)
        )
    }

    private func getContentDigest(for node: Node) throws -> FileContentDigest? {
        // Only needed for photos
        if let photo = node as? CoreDataPhoto {
            return try photo.photoRevision.getContentDigest()
        } else {
            return nil
        }
    }

    public func readNodeWithHashKey(identifier: AnyVolumeIdentifier) async throws -> NodeParentCryptoMaterial {
        return try await moc.perform {
            let node = try Node.fetchOrThrow(identifier: identifier, allowSubclasses: true, in: self.moc)
            let nodeWithHashKey = try node as? NodeWithNodeHashKey ?! "Invalid node"
            return try nodeWithHashKey.encrypting()
        }
    }
}
