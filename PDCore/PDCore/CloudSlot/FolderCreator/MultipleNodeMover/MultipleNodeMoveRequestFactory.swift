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
import PDClient

public protocol MultipleMovingNodeLinkFactoryProtocol {
    func prepareNodeLinks(
        for nodes: [Node],
        newParentInfo: NodeParentCryptoMaterial
    ) async -> MultipleMovingNodesData
}

public struct MultipleMovingNodesData {
    let infos: [MultipleMovingNode.LinkInfo]
    let error: Error?
}

public final class MultipleMovingNodeLinkFactory: MultipleMovingNodeLinkFactoryProtocol {
    private let infoReader: NodeCryptoMaterialReaderProtocol
    private let moc: NSManagedObjectContext

    public init(infoReader: NodeCryptoMaterialReaderProtocol, moc: NSManagedObjectContext) {
        self.infoReader = infoReader
        self.moc = moc
    }

    public func prepareNodeLinks(
        for nodes: [Node],
        newParentInfo: NodeParentCryptoMaterial
    ) async -> MultipleMovingNodesData {
        return await withTaskGroup(
            of: Result<MultipleMovingNode.LinkInfo, Error>.self,
            returning: MultipleMovingNodesData.self
        ) { [weak self] group in
            guard let self else {
                return MultipleMovingNodesData(infos: [], error: nil)
            }

            for node in nodes {
                group.addTask {
                    do {
                        let info = try await self.prepareNodeLink(
                            for: node,
                            newParentInfo: newParentInfo
                        )
                        return .success(info)
                    } catch {
                        Log.error(error: error, domain: .networking)
                        return .failure(error)
                    }
                }
            }
            var infos: [MultipleMovingNode.LinkInfo] = []
            var error: Error?
            for await result in group {
                switch result {
                case let .success(info):
                    infos.append(info)
                case let .failure(infoError):
                    error = infoError
                }
            }
            return MultipleMovingNodesData(
                infos: infos,
                error: error
            )
        }
    }
}

// MARK: - Prepare link information from the given node
extension MultipleMovingNodeLinkFactory {
    private func prepareNodeLink(
        for node: Node,
        newParentInfo: NodeParentCryptoMaterial
    ) async throws -> MultipleMovingNode.LinkInfo {
        let identifier = try await node.moc?.perform { node.identifier.any() } ?! "Invalid node"
        let cryptoInfo = try await infoReader.readNode(identifier: identifier)

        // Move is only permitted in context of a single volume
        guard identifier.volumeID == newParentInfo.volumeID else {
            throw node.invalidState("The node and the new parent should inside the same volume")
        }

        let validatedName = try cryptoInfo.oldDecryptedNodeName.validateNodeName(validator: NameValidations.iosName)

        let link: MoveMultipleEndpoint.Link
        if cryptoInfo.isAnonymous {
            link = try prepareRequestParameterForAnonymous(
                newParentInfo: newParentInfo,
                node: node,
                cryptoInfo: cryptoInfo,
                validatedNewName: validatedName
            )
        } else {
            link = try prepareRequestParameterForNormal(
                newParentInfo: newParentInfo,
                node: node,
                cryptoInfo: cryptoInfo,
                validatedNewName: validatedName
            )
        }
        return .init(
            link: link,
            isAnonymous: cryptoInfo.isAnonymous,
            signatureEmail: cryptoInfo.signersKit.address.email
        )
    }

    private func prepareRequestParameterForAnonymous(
        newParentInfo: NodeParentCryptoMaterial,
        node: Node,
        cryptoInfo: NodeCryptoMaterial,
        validatedNewName: String
    ) throws -> MoveMultipleEndpoint.Link {
        let newEncryptedName = try node.encryptName(
            cleartext: validatedNewName,
            parentKey: newParentInfo.nodeKey,
            signersKit: cryptoInfo.signersKit
        )
        let newNameHash = try Encryptor.hmac(filename: validatedNewName, parentHashKey: newParentInfo.hashKey)

        let updatedCredential = try Encryptor.updateNodeKeys(
            passphraseString: cryptoInfo.oldDecryptedNodePassphrase,
            addressPassphrase: cryptoInfo.signersKit.addressPassphrase,
            addressPrivateKey: cryptoInfo.signersKit.addressKey.privateKey,
            parentKey: newParentInfo.nodeKey
        )

        return .init(
            linkID: cryptoInfo.id.id,
            name: newEncryptedName,
            nodePassphrase: updatedCredential.nodePassphrase,
            hash: newNameHash,
            originalHash: cryptoInfo.oldNameHash,
            contentHash: try makeContentHash(node: cryptoInfo, parent: newParentInfo),
            nodePassphraseSignature: updatedCredential.signature
        )
    }

    private func prepareRequestParameterForNormal(
        newParentInfo: NodeParentCryptoMaterial,
        node: Node,
        cryptoInfo: NodeCryptoMaterial,
        validatedNewName: String
    ) throws -> MoveMultipleEndpoint.Link {
        let newNodePassphrase = try node.reencryptNodePassphrase(
            oldNodePassphrase: cryptoInfo.oldNodePassphrase,
            oldParentKey: cryptoInfo.oldParentKey,
            oldParentPassphrase: cryptoInfo.oldParentPassphrase,
            newParentKey: newParentInfo.nodeKey
        )
        let newEncryptedName = try node.renameNode(
            oldEncryptedName: cryptoInfo.oldNodeName,
            oldParentKey: cryptoInfo.oldParentKey,
            oldParentPassphrase: cryptoInfo.oldParentPassphrase,
            newClearName: validatedNewName,
            newParentKey: newParentInfo.nodeKey,
            signersKit: cryptoInfo.signersKit
        )
        let newNameHash = try Encryptor.hmac(filename: validatedNewName, parentHashKey: newParentInfo.hashKey)

        return .init(
            linkID: cryptoInfo.id.id,
            name: newEncryptedName,
            nodePassphrase: newNodePassphrase,
            hash: newNameHash,
            originalHash: cryptoInfo.oldNameHash,
            contentHash: try makeContentHash(node: cryptoInfo, parent: newParentInfo),
            nodePassphraseSignature: nil
        )
    }

    private func makeContentHash(node: NodeCryptoMaterial, parent: NodeParentCryptoMaterial) throws -> String? {
        switch node.contentDigest {
        case let .contentDigest(digest):
            return try Encryptor().makeHmac(string: digest, hashKey: parent.hashKey)
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
