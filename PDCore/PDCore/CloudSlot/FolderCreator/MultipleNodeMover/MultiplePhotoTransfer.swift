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

public protocol MultiplePhotoTransferProtocol {
    func move(photos: [CoreDataPhoto], to photoRoot: Folder) async throws
}

/// Transfer photos from and to albums
public final class MultiplePhotoTransfer: MultiplePhotoTransferProtocol {
    private let batchSize = 100
    private let client: MoveNodeClient
    private let infoReader: NodeCryptoMaterialReaderProtocol
    private let linksFactory: MultipleMovingNodeLinkFactoryProtocol
    private let localUpdater: MovedNodesUpdateRepositoryProtocol
    private let moc: NSManagedObjectContext

    public init(
        client: MoveNodeClient,
        infoReader: NodeCryptoMaterialReaderProtocol,
        linksFactory: MultipleMovingNodeLinkFactoryProtocol,
        localUpdater: MovedNodesUpdateRepositoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.client = client
        self.infoReader = infoReader
        self.linksFactory = linksFactory
        self.localUpdater = localUpdater
        self.moc = moc
    }

    /// - Parameters:
    ///   - photos: Main photo only
    ///   - photoRoot: photo stream root folder
    public func move(photos: [CoreDataPhoto], to photoRoot: Folder) async throws {
        let parentIdentifier = try await photoRoot.moc?.perform { photoRoot.identifier.any() } ?! "Invalid parent"
        let newParentInfo = try await infoReader.readNodeWithHashKey(identifier: parentIdentifier)
        let batches = await makeAllBatches(photos: photos)

        // Need to separate infos, since normal vs anonymous need separate requests
        let normalInfosData = await makeLinkInfos(from: batches.normal, newParentInfo: newParentInfo)
        let normalInfos = normalInfosData.map(\.infos)
        let anonymousInfosData = await makeLinkInfos(from: batches.anonymous, newParentInfo: newParentInfo)
        let anonymousInfos = anonymousInfosData.map(\.infos)

        guard let signatureEmail = (normalInfos + anonymousInfos).first?.first?.signatureEmail else {
            return
        }

        let normalResult = await execute(
            batchInfos: normalInfos,
            signatureEmail: signatureEmail,
            newParentInfo: newParentInfo,
            isAnonymous: false
        )
        let anonymousResult = await execute(
            batchInfos: anonymousInfos,
            signatureEmail: signatureEmail,
            newParentInfo: newParentInfo,
            isAnonymous: true
        )
        let allInfos = normalInfos + anonymousInfos
        let successIds = normalResult.successIds + anonymousResult.successIds
        let requestErrors = normalResult.errors + anonymousResult.errors

        let successInfos = allInfos.flatMap { $0 }.filter { successIds.contains($0.link.LinkID) }
        try await localUpdater.updateLocalDB(
            newParent: photoRoot,
            nodes: (batches.normal + batches.anonymous).flatMap { $0 },
            infos: successInfos
        )

        if let error = requestErrors.first {
            // Error during updating remote state
            throw error
        }
        if let error = normalInfosData.compactMap(\.error).first ?? anonymousInfosData.compactMap(\.error).first {
            // Error during reading local state
            throw error
        }
    }
}

extension MultiplePhotoTransfer {
    struct NodeBatches {
        let normal: [[Node]]
        let anonymous: [[Node]]
    }

    struct LinkInfos {
        let normal: [[MultipleMovingNode.LinkInfo]]
        let anonymous: [[MultipleMovingNode.LinkInfo]]
    }

    struct RemoteResult {
        let successIds: [String]
        let errors: [Error]
    }

    private func makeAllBatches(photos: [CoreDataPhoto]) async -> NodeBatches {
        await moc.perform {
            let photos = photos.map { $0.in(moc: self.moc) }
            let normalPhotos = photos.filter { !$0.isAnonymous }
            let anonymousPhotos = photos.filter { $0.isAnonymous }
            return NodeBatches(
                normal: self.makeBatches(photos: normalPhotos),
                anonymous: self.makeBatches(photos: anonymousPhotos)
            )
        }
    }

    private func makeBatches(photos: [CoreDataPhoto]) -> [[Node]] {
        var batches: [[CoreDataPhoto]] = []
        var batch: [CoreDataPhoto] = []
        for photo in photos {
            let temp = [photo] + Array(photo.children)
            if batch.count + temp.count <= self.batchSize {
                batch.append(contentsOf: temp)
            } else {
                batches.append(batch)
                batch = temp
            }
        }
        if !batch.isEmpty {
            batches.append(batch)
        }
        return batches
    }

    private func makeLinkInfos(
        from batches: [[Node]],
        newParentInfo: NodeParentCryptoMaterial
    ) async -> [MultipleMovingNodesData] {
        await withTaskGroup(
            of: MultipleMovingNodesData.self,
            returning: [MultipleMovingNodesData].self
        ) { [weak self] group in
            guard let self else { return [] }
            for batch in batches {
                group.addTask {
                    await self.linksFactory.prepareNodeLinks(for: batch, newParentInfo: newParentInfo)
                }
            }
            var infos: [MultipleMovingNodesData] = []
            for await result in group {
                infos.append(result)
            }
            return infos
        }
    }

    private func execute(
        batchInfos: [[MultipleMovingNode.LinkInfo]],
        signatureEmail: String,
        newParentInfo: NodeParentCryptoMaterial,
        isAnonymous: Bool
    ) async -> RemoteResult {
        await withTaskGroup(
            of: ([String], Error?).self,
            returning: RemoteResult.self
        ) { [weak self] group in
            guard let self else { return RemoteResult(successIds: [], errors: []) }
            for info in batchInfos {
                group.addTask {
                    do {
                        let successID = try await self.execute(
                            linkInfos: info,
                            nameSignatureEmail: signatureEmail,
                            signatureEmail: isAnonymous ? signatureEmail : nil,
                            newParentInfo: newParentInfo
                        )
                        return (successID, nil)
                    } catch {
                        return ([], error)
                    }
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
            return RemoteResult(successIds: successIDs, errors: requestErrors)
        }
    }

    private func execute(
        linkInfos: [MultipleMovingNode.LinkInfo],
        nameSignatureEmail: String,
        signatureEmail: String?,
        newParentInfo: NodeParentCryptoMaterial
    ) async throws -> [String] {
        let links = linkInfos.map(\.link)
        let parameters = self.prepareRequestParameter(
            links: links,
            newParentID: newParentInfo.id,
            nameSignatureEmail: nameSignatureEmail,
            signatureEmail: signatureEmail
        )

        try await self.client.transferMultiple(volumeID: newParentInfo.volumeID, parameters: parameters)
        return links.map(\.LinkID)
    }

    private func prepareRequestParameter(
        links: [MoveMultipleEndpoint.Link],
        newParentID: String,
        nameSignatureEmail: String,
        signatureEmail: String?
    ) -> TransferMultipleEndpoint.Parameters {
        return .init(
            parentLinkID: newParentID,
            links: links,
            nameSignatureEmail: nameSignatureEmail,
            signatureEmail: signatureEmail
        )
    }
}
