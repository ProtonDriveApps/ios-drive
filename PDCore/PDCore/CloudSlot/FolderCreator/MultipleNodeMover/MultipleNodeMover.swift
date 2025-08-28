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

import Foundation
import PDClient
import CoreData

public protocol MultipleNodeMoverProtocol {
    func move(_ nodes: [Node], to newParent: Folder) async throws
}

/// Generate request parameters by the given nodes(File / Folder) doing request and update local database
/// NOTE: this class doesn't handle duplicated check
public final class MultipleNodeMover: MultipleNodeMoverProtocol {
    /// Typealias for one of the methods of PDClient's Client.
    public typealias CloudMultipleNodeMover = (Client.VolumeID, MoveMultipleEndpoint.Parameters) async throws -> Void

    private let moc: NSManagedObjectContext
    private let cloudMultipleNodeMover: CloudMultipleNodeMover
    private let infoReader: NodeCryptoMaterialReaderProtocol
    private let linksFactory: MultipleMovingNodeLinkFactoryProtocol
    private let batchSize = 100

    public init(
        cloudMultipleNodeMover: @escaping CloudMultipleNodeMover,
        moc: NSManagedObjectContext,
        infoReader: NodeCryptoMaterialReaderProtocol,
        linksFactory: MultipleMovingNodeLinkFactoryProtocol
    ) {
        self.moc = moc
        self.cloudMultipleNodeMover = cloudMultipleNodeMover
        self.infoReader = infoReader
        self.linksFactory = linksFactory
    }

    public func move(_ nodes: [Node], to newParent: Folder) async throws {
        let parentIdentifier = try await newParent.moc?.perform { newParent.identifier.any() } ?! "Invalid parent"
        let newParentInfo = try await infoReader.readNodeWithHashKey(identifier: parentIdentifier)
        let infosData = await linksFactory.prepareNodeLinks(for: nodes, newParentInfo: newParentInfo)
        guard let signatureEmail = infosData.infos.first?.signatureEmail else { return }
        let (successLinks, requestError) = await execute(
            linkInfos: infosData.infos,
            signatureEmail: signatureEmail,
            newParentInfo: newParentInfo
        )
        let successInfos = infosData.infos.filter { successLinks.contains($0.link.LinkID) }
        try await updateLocalDB(newParent: newParent, nodes: nodes, infos: successInfos)
        if let requestError {
            throw requestError
        }
        if let infosError = infosData.error {
            throw infosError
        }
    }
}

// MARK: - Helper functions
extension MultipleNodeMover {
    private func execute(
        batchInfos: [[MultipleMovingNode.LinkInfo]],
        signatureEmail: String,
        newParentInfo: NodeParentCryptoMaterial
    ) async -> ([String], [Error]) {
        await withTaskGroup(
            of: ([String], Error?).self,
            returning: ([String], [any Error]).self
        ) { [weak self] group in
            guard let self else { return ([], []) }
            for info in batchInfos {
                group.addTask {
                    let (successLinks, requestError) = await self.execute(
                        linkInfos: info,
                        signatureEmail: signatureEmail,
                        newParentInfo: newParentInfo
                    )
                    return (successLinks, requestError)
                }
            }
            var successIDs: [String] = []
            var requestErrors: [Error] = []
            for await result in group {
                successIDs.append(contentsOf: result.0)
                if let error = result.1 {
                    requestErrors.append(error)
                }
            }
            return (successIDs, requestErrors)
        }
    }

    private func execute(
        linkInfos: [MultipleMovingNode.LinkInfo],
        signatureEmail: String,
        newParentInfo: NodeParentCryptoMaterial
    ) async -> ([String], Error?){
        let links = linkInfos.map(\.link)
        let batches = links.splitInGroups(of: batchSize)

        let results = await withTaskGroup(
            of: Result<[String], Error>.self,
            returning: [Result<[String], Error>].self
        ) { [weak self] group in
            guard let self else { return [] }
            for batch in batches {
                group.addTask {
                    do {
                        let parameters = self.prepareRequestParameter(
                            links: batch,
                            newParentID: newParentInfo.id,
                            signatureEmail: signatureEmail
                        )

                        try await self.cloudMultipleNodeMover(newParentInfo.volumeID, parameters)
                        return .success(batch.map(\.LinkID))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var results: [Result<[String], Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        var successLinks: [String] = []
        var requestError: Error?
        for result in results {
            switch result {
            case .success(let ids):
                successLinks.append(contentsOf: ids)
            case .failure(let error):
                requestError = error
            }
        }
        return (successLinks, requestError)
    }

    private func prepareRequestParameter(
        links: [MoveMultipleEndpoint.Link],
        newParentID: String,
        signatureEmail: String
    ) -> MoveMultipleEndpoint.Parameters {
        return .init(
            parentLinkID: newParentID,
            links: links,
            nameSignatureEmail: signatureEmail,
            signatureEmail: signatureEmail,
            newShareID: nil
        )
    }

    private func updateLocalDB(newParent: Folder, nodes: [Node], infos: [MultipleMovingNode.LinkInfo]) async throws {
        try await moc.perform {
            let newParent = newParent.in(moc: self.moc)
            for node in nodes {
                let node = node.in(moc: self.moc)
                guard let info = infos.first(where: { $0.link.LinkID == node.id }) else { continue }
                let link = info.link

                node.name = link.Name
                node.nodeHash = link.Hash
                node.nodePassphrase = link.NodePassphrase
                if info.isAnonymous {
                    if let signature = link.NodePassphraseSignature {
                        node.nodePassphraseSignature = signature
                    }
                    node.nameSignatureEmail = info.signatureEmail
                    node.signatureEmail = info.signatureEmail
                }

                node.parentFolder = newParent
            }

            try self.moc.saveOrRollback()
        }
    }
}
