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
import ProtonCoreUtilities

extension Client {
    public func postAvailableHashes(shareID: Share.ShareID, folderID: Link.LinkID, parameters: AvailableHashesParameters) async throws -> AvailableHashesResponse {
        guard let credential = self.credentialProvider.clientCredential() else {
            throw Errors.couldNotObtainCredential
        }
        let endpoint = AvailableHashesEndpoint(shareID: shareID, folderID: folderID, parameters: parameters, service: self.service, credential: credential)
        return try await request(endpoint)
    }

    public func getShareUrl(volumeID: VolumeID, page: Int, pageSize: Int) async throws -> ListShareURLEndpoint.Response {
        let credential = try credential()

        let endpoint = ListShareURLEndpoint(
            parameters: .init(
                volumeId: volumeID,
                page: page,
                pageSize: pageSize
            ),
            service: service,
            credential: credential
        )

        return try await request(endpoint)
    }
    
    public func listVolumeTrash(volumeID: VolumeID, page: Int, pageSize: Int) async throws -> ListVolumeTrashEndpoint.Response {
        let credential = try credential()

        let endpoint = ListVolumeTrashEndpoint(
            parameters: .init(
                volumeId: volumeID,
                page: page,
                pageSize: pageSize
            ),
            service: service,
            credential: credential
        )

        return try await request(endpoint)
    }

    @discardableResult
    public func trashNodes(parameters: TrashLinksParameters, breadcrumbs: Breadcrumbs) async throws -> MultipleLinkResponse {
        guard let credential = self.credentialProvider.clientCredential() else {
            throw Errors.couldNotObtainCredential
        }
        let endpoint = try TrashLinkEndpoint(parameters: parameters, service: service, credential: credential, breadcrumbs: breadcrumbs.collect())
        return try await request(endpoint)
    }
    
    public func getLinksMetadata(with parameters: LinksMetadataParameters) async throws -> LinksResponse {
        let endpoint = LinksMetadataEndpoint(service: service, credential: try credential(), parameters: parameters)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }
    
    public func getFolderChildren(_ shareID: ShareID, folderID: FolderID, parameters: [FolderChildrenEndpointParameters]? = nil) async throws -> [Link] {
        let endpoint = FolderChildrenEndpoint(shareID: shareID, folderID: folderID, parameters: parameters, service: service, credential: try credential())
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue)).links
    }

    public func getVolumes() async throws -> [Volume] {
        let credential = try credential()
        let endpoint = VolumesEndpoint(service: self.service, credential: credential)
        return try await request(endpoint).volumes
    }

    public func getShares() async throws -> [ShareShort] {
        let credential = try credential()
        let endpoint = SharesEndpoint(service: service, credential: credential)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue)).shares
    }

    public func getShare(_ id: ShareID) async throws -> Share {
        let credential = try credential()
        let endpoint = ShareEndpoint(shareID: id, service: service, credential: credential)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }

    public func getRevision(shareID: Share.ShareID, fileID: Link.LinkID, revisionID: Revision.RevisionID) async throws -> RevisionShort {
        let credential = try credential()
        let endpoint = GetRevisionEndpoint(shareID: shareID, fileID: fileID, revisionID: revisionID, service: service, credential: credential)
        return try await request(endpoint).revision
    }

    public func getLink(shareID: ShareID, linkID: LinkID, breadcrumbs: Breadcrumbs) async throws -> Link {
        let endpoint = try LinkEndpoint(shareID: shareID, linkID: linkID, service: self.service, credential: try credential(), breadcrumbs: breadcrumbs.collect())
        let response = try await request(endpoint)
        return response.link
    }

    public func deleteChildren(shareID: ShareID, folderID: LinkID, linkIDs: [LinkID]) async throws -> MultiLinkResponse {
        let parameters = DeleteLinkInFolderEndpoint.Parameters(shareID: shareID, folderID: folderID, linkIDs: linkIDs)
        let endpoint = DeleteLinkInFolderEndpoint(parameters: parameters, service: service, credential: try credential())
        return try await request(endpoint)
    }

    public func createFolder(shareID: ShareID, parameters: NewFolderParameters) async throws -> NewFolder {
        let credential = try credential()
        let endpoint = NewFolderEndpoint(shareID: shareID, parameters: parameters, service: service, credential: credential)
        return try await request(endpoint).folder
    }

    public func renameEntry(shareID: Share.ShareID, linkID: Link.LinkID, parameters: RenameNodeParameters) async throws {
        let credential = try credential()
        let endpoint = RenameNodeEndpoint(shareID: shareID, nodeID: linkID, parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    public func moveEntry(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: MoveEntryEndpoint.Parameters) async throws {
        let credential = try credential()
        let endpoint = MoveEntryEndpoint(shareID: shareID, nodeID: nodeID, parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    public func createShare(volumeID: Volume.VolumeID, parameters: NewShareParameters) async throws -> NewShareShort {
        let credential = try credential()
        let endpoint = NewShareEndpoint(volumeID: volumeID, parameters: parameters, service: self.service, credential: credential)
        return try await request(endpoint).share
    }
}
