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

    public func getShareUrl(shareID: ShareID) async throws -> [ShareURLMeta] {
        let endpoint = ShareURLEndpoint(shareID: shareID, service: self.service, credential: try credential())
        let response = try await request(endpoint)
        return response.shareURLs
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

    public func getRevision(revisionID: String, fileID: String, shareID: String) async throws -> Revision {
        let endpoint = RevisionEndpoint(shareID: shareID, fileID: fileID, revisionID: revisionID, service: service, credential: try credential())
        let request = try await request(endpoint)
        return request.revision
    }

    public func getNode(shareID: ShareID, nodeID: Link.LinkID) async throws -> Link {
        let endpoint = try LinkEndpoint(shareID: shareID, linkID: nodeID, service: service, credential: try credential(), breadcrumbs: .startCollecting())
        let response = try await performRequest(on: endpoint)
        return response.link
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

public protocol SharesListing {
    func listShares() async throws -> [ListSharesEndpoint.Response.Share]
}

extension Client: SharesListing {
    public func listShares() async throws -> [ListSharesEndpoint.Response.Share] {
        let parameters = ListSharesEndpoint.Parameters(shareType: nil, showAll: .default)
        let endpoint = ListSharesEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)

        return response.shares
    }
}

extension Client {
    public func bootstrapRoot(shareID: String, rootLinkID: String) async throws -> Root {
        async let share = try bootstrapShare(id: shareID)
        async let root = try getLinkMetadata(parameters: .init(shareId: shareID, linkIds: [rootLinkID]))

        return try await Root(link: root, share: share)
    }

    public func bootstrapShare(id: String) async throws -> GetShareBootstrapEndpoint.Response {
        let credential = try credential()
        let endpoint = GetShareBootstrapEndpoint(shareID: id, service: service, credential: credential)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }

    public func getLinkMetadata(parameters: LinksMetadataParameters) async throws -> Link {
        let endpoint = LinksMetadataEndpoint(service: service, credential: try credential(), parameters: parameters)
        let response = try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
        guard let link = response.links.first else {
            throw Errors.invalidResponse
        }
        return link
    }
}

public protocol UserSettingAPIClient {
    func getDriveEntitlements() async throws -> DriveEntitlementsEndpoint.DriveEntitlements
}

extension Client: UserSettingAPIClient {
    public func getDriveEntitlements() async throws -> DriveEntitlementsEndpoint.DriveEntitlements {
        let credential = try credential()
        let endpoint = DriveEntitlementsEndpoint(service: service, credential: credential)
        return try await request(endpoint).entitlements
    }
}

extension Client {
    public func postVolume(parameters: NewVolumeParameters) async throws -> NewVolume {
        let credential = try credential()
        let endpoint = NewVolumeEndpoint(parameters: parameters, service: service, credential: credential)
        return try await request(endpoint).volume
    }
}

extension Client {
    public func createShareURL(shareID: Share.ShareID, parameters: NewShareURLParameters) async throws -> ShareURLMeta {
        let endpoint = NewShareURLEndpoint(shareID: shareID, parameters: parameters, service: self.service, credential: try credential())
        let response = try await request(endpoint)
        return response.shareURL
    }

    public func deleteShare(id: ShareID, force: Bool) async throws {
        let endpoint = DeleteShareEndpoint(shareID: id, force: force, service: self.service, credential: try credential())
        _ = try await request(endpoint)
    }

    public func deleteShareURL(id: String, shareID: String) async throws {
        let endpoint = DeleteSecureLinkEndpoint(shareID: shareID, shareURLID: id, service: self.service, credential: try credential())
        _ = try await request(endpoint)
    }

    public func updateShareURL<Parameters: EditShareURLParameters>(shareURLID: ShareURLMeta.ID, shareID: Share.ShareID, parameters: Parameters) async throws -> ShareURLMeta {
        let endpoint = EditShareURLEndpoint(shareURLID: shareURLID, shareID: shareID, parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.shareURL
    }

    public func getModulusSRP() async throws -> Modulus {
        let endpoint = ShareSRPEndpoint(service: self.service)
        let response = try await request(endpoint)
        return Modulus(modulus: response.modulus, modulusID: response.modulusID)
    }
}

public protocol ShareInvitationAPIClient {
    func listInvitations(shareID: Share.ShareID) async throws -> [ShareMemberInvitation]
    func listExternalInvitations(shareID: Share.ShareID) async throws -> [ExternalInvitation]
    func deleteInvitation(shareID: Share.ShareID, invitationID: String) async throws
    func deleteExternalInvitation(shareID: Share.ShareID, invitationID: String) async throws
    func resendInvitationEmail(shareID: Share.ShareID, invitationID: String) async throws
    func resendExternalInvitationEmail(shareID: Share.ShareID, invitationID: String) async throws
    func inviteProtonUser(
        shareID: Share.ShareID,
        body: InviteProtonUserEndpoint.Parameters.Body
    ) async throws -> ShareMemberInvitation
    func inviteExternalUser(
        shareID: Share.ShareID,
        body: InviteExternalUserEndpoint.Parameters.Body
    ) async throws -> ExternalInvitation
    func updateInvitationPermissions(
        shareID: Share.ShareID,
        invitationID: String,
        permissions: AccessPermission
    ) async throws
    func updateExternalInvitationPermissions(
        shareID: Share.ShareID,
        invitationID: String,
        permissions: AccessPermission
    ) async throws
}

extension Client: ShareInvitationAPIClient {
    public func listInvitations(shareID: Share.ShareID) async throws -> [ShareMemberInvitation] {
        let credential = try credential()
        let endpoint = ShareInvitationListEndpoint(shareID: shareID, service: service, credential: credential)
        return try await request(endpoint).invitations
    }
    
    public func listExternalInvitations(shareID: Share.ShareID) async throws -> [ExternalInvitation] {
        let credential = try credential()
        let endpoint = ListExternalInvitationsEndpoint(shareID: shareID, service: service, credential: credential)
        return try await request(endpoint).externalInvitations
    }
    
    public func deleteInvitation(shareID: Share.ShareID, invitationID: String) async throws {
        let credential = try credential()
        let endpoint = DeleteInvitationEndpoint(
            shareID: shareID,
            invitationID: invitationID,
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
    
    public func deleteExternalInvitation(shareID: Share.ShareID, invitationID: String) async throws {
        let credential = try credential()
        let endpoint = DeleteExternalInvitationEndpoint(
            shareID: shareID,
            invitationID: invitationID,
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
    
    public func resendInvitationEmail(shareID: Share.ShareID, invitationID: String) async throws {
        let credential = try credential()
        let endpoint = ResendInvitationEmailEndpoint(
            shareID: shareID,
            invitationID: invitationID,
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
    
    public func resendExternalInvitationEmail(shareID: Share.ShareID, invitationID: String) async throws {
        let credential = try credential()
        let endpoint = ResendExternalInvitationEmailEndpoint(
            shareID: shareID,
            invitationID: invitationID,
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
    
    public func inviteProtonUser(
        shareID: Share.ShareID,
        body: InviteProtonUserEndpoint.Parameters.Body
    ) async throws -> ShareMemberInvitation {
        let credential = try credential()
        let endpoint = try InviteProtonUserEndpoint(
            parameters: .init(shareID: shareID, body: body),
            service: service,
            credential: credential
        )
        return try await request(endpoint).invitation
    }
    
    public func inviteExternalUser(
        shareID: Share.ShareID,
        body: InviteExternalUserEndpoint.Parameters.Body
    ) async throws -> ExternalInvitation {
        let credential = try credential()
        let endpoint = try InviteExternalUserEndpoint(
            parameters: .init(shareID: shareID, body: body),
            service: service,
            credential: credential
        )
        return try await request(endpoint).externalInvitation
    }
    
    public func updateInvitationPermissions(
        shareID: Share.ShareID,
        invitationID: String,
        permissions: AccessPermission
    ) async throws {
        let credential = try credential()
        let endpoint = try UpdateInvitationPermissionsEndpoint(
            shareID: shareID,
            invitationID: invitationID,
            parameters: .init(permissions: permissions),
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
    
    public func updateExternalInvitationPermissions(
        shareID: Share.ShareID,
        invitationID: String,
        permissions: AccessPermission
    ) async throws {
        let credential = try credential()
        let endpoint = try UpdateExternalInvitationPermissionsEndpoint(
            shareID: shareID,
            invitationID: invitationID,
            parameters: .init(permissions: permissions),
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
}

// MARK: - Sharing member
public protocol ShareMemberAPIClient {
    func getShare(_ id: Share.ShareID) async throws -> Share
    func deleteShare(id: Share.ShareID, force: Bool) async throws
    func listShareMember(id: Share.ShareID) async throws -> [ShareMember]
    func removeMember(shareID: String, memberID: String) async throws
    func updateShareMemberPermissions(
        shareID: Share.ShareID,
        memberID: String,
        permissions: AccessPermission
    ) async throws
}

extension Client: ShareMemberAPIClient {
    public func listShareMember(id: Share.ShareID) async throws -> [ShareMember] {
        let credential = try credential()
        let endpoint = ListShareMemberEndPoint(shareID: id, service: service, credential: credential)
        return try await request(endpoint).members
    }
    
    public func updateShareMemberPermissions(
        shareID: Share.ShareID,
        memberID: String,
        permissions: AccessPermission
    ) async throws {
        let credential = try credential()
        let endpoint = try UpdateShareMemberPermissionsEndpoint(
            shareID: shareID,
            memberID: memberID,
            parameters: .init(permissions: permissions),
            service: service,
            credential: credential
        )
        _ = try await request(endpoint)
    }
    
    public func removeMember(shareID: String, memberID: String) async throws {
        let credential = try credential()
        let endpoint = RemoveShareMemberEndpoint(shareID: shareID, memberID: memberID, service: self.service, credential: credential)
        _ = try await request(endpoint)
    }
}

extension Client: LinksMetadataRepository {
    public func getLinksMetadata(with parameters: LinksMetadataParameters) async throws -> LinksResponse {
        let endpoint = LinksMetadataEndpoint(service: service, credential: try credential(), parameters: parameters)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }
}
