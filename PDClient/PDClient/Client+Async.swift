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

    public func createShare(volumeID: Volume.VolumeID, parameters: NewShareParameters) async throws -> NewShareShort {
        let credential = try credential()
        let endpoint = NewShareEndpoint(volumeID: volumeID, parameters: parameters, service: self.service, credential: credential)
        return try await request(endpoint).share
    }
}

public protocol MoveNodeClient {
    func moveEntry(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: MoveEntryEndpoint.Parameters) async throws
    func moveMultiple(volumeID: Volume.VolumeID, parameters: MoveMultipleEndpoint.Parameters) async throws
    func transferMultiple(volumeID: Volume.VolumeID, parameters: TransferMultipleEndpoint.Parameters) async throws
}

extension Client: MoveNodeClient {
    public func moveEntry(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: MoveEntryEndpoint.Parameters) async throws {
        let credential = try credential()
        let endpoint = MoveEntryEndpoint(shareID: shareID, nodeID: nodeID, parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    public func moveMultiple(volumeID: VolumeID, parameters: MoveMultipleEndpoint.Parameters) async throws {
        let credential = try credential()
        let endpoint = MoveMultipleEndpoint(volumeID: volumeID, parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    public func transferMultiple(volumeID: VolumeID, parameters: TransferMultipleEndpoint.Parameters) async throws {
        let credential = try credential()
        let endpoint = TransferMultipleEndpoint(volumeID: volumeID, parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }
}

public protocol SharesListing {
    func listShares() async throws -> [ListSharesEndpoint.Response.Share]
    func listShares(parameters: ListSharesEndpoint.Parameters) async throws -> [ListSharesEndpoint.Response.Share]
}

extension Client: SharesListing {
    public func listShares() async throws -> [ListSharesEndpoint.Response.Share] {
        let parameters = ListSharesEndpoint.Parameters(shareType: nil, showAll: .default)
        return try await listShares(parameters: parameters)
    }

    public func listShares(parameters: ListSharesEndpoint.Parameters) async throws -> [ListSharesEndpoint.Response.Share] {
        let endpoint = ListSharesEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.shares
    }
}

public protocol BootstrapRootClient {
    func bootstrapRoot(shareID: String, rootLinkID: String) async throws -> Root
}

extension Client: BootstrapRootClient {
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

// MARK: - RemoteLinksMetadataByVolumeDataSource
public protocol RemoteLinksMetadataByVolumeDataSource {
    func getMetadata(forLinks links: [String], inVolume volume: String) async throws -> LinksResponseByVolume
}

extension Client: RemoteLinksMetadataByVolumeDataSource {
    public func getMetadata(forLinks links: [String], inVolume volume: String) async throws -> LinksResponseByVolume {
        let parameters = LinksMetadataByVolumeParameters(volumeId: volume, linkIds: links)
        let endpoint = LinksMetadataByVolumeEndpoint(service: service, credential: try credential(), parameters: parameters)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }
}

// MARK: - RemoteShareMetadataDataSource
public protocol RemoteShareMetadataDataSource {
     func getMetadata(forShare share: String) async throws -> ShareMetadata
}

extension Client: RemoteShareMetadataDataSource {
    public func getMetadata(forShare share: String) async throws -> ShareMetadata {
        let credential = try credential()
        let endpoint = GetShareBootstrapEndpoint(shareID: share, service: service, credential: credential)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }
}

// MARK: - TrashRepository
public protocol TrashRepository {
    func emptyVolumeTrash(volumeId: Volume.VolumeID) async throws
    func deleteTrashed(volumeId: Volume.VolumeID, linkIds: [Link.LinkID]) async throws -> [PartialFailure]
    func trashVolumeNodes(parameters: TrashVolumeLinksParameters, breadcrumbs: Breadcrumbs) async throws -> MultipleLinkResponse
    func restoreVolumeTrashedNodes(volumeID: String, linkIDs: [String]) async throws -> [PartialFailure]

    func retoreTrashNode(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws -> [PartialFailure]
}

extension Client: TrashRepository {
    public func emptyVolumeTrash(volumeId: Volume.VolumeID) async throws {
        let endpoint = EmptyVolumeTrashEndpoint(volumeId: volumeId, service: service, credential: try credential())
        do {
            _ = try await request(endpoint)
        } catch {
            if error.httpCode == 202 {
                // ProtonCore throws when `statusCode != 200`. This is a hack around the limitation since this API
                // actually returns 202 in success case.
                return
            } else {
                throw error
            }
        }
    }

    public func deleteTrashed(volumeId: Volume.VolumeID, linkIds: [Link.LinkID]) async throws -> [PartialFailure] {
        let parameters = DeleteMultipleParameters(volumeId: volumeId, linkIds: linkIds)
        let endpoint = DeleteMultipleEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.responses.compactMap(PartialFailure.init)
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
    public func trashVolumeNodes(parameters: TrashVolumeLinksParameters, breadcrumbs: Breadcrumbs) async throws -> MultipleLinkResponse {
        guard let credential = self.credentialProvider.clientCredential() else {
            throw Errors.couldNotObtainCredential
        }
        let endpoint = try TrashVolumeLinkEndpoint(parameters: parameters, service: service, credential: credential, breadcrumbs: breadcrumbs)
        return try await request(endpoint)
    }

    public func restoreVolumeTrashedNodes(volumeID: String, linkIDs: [String]) async throws -> [PartialFailure] {
        let parameters: RestoreVolumeLinkEndpoint.Parameters = .init(volumeID: volumeID, linkIDs: linkIDs)
        let endpoint = RestoreVolumeLinkEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.responses.compactMap(PartialFailure.init)
    }

    // Legacy, todo when album / computer is released, this can be removed
    @discardableResult
    public func trashNodes(parameters: TrashLinksParameters, breadcrumbs: Breadcrumbs) async throws -> MultipleLinkResponse {
        guard let credential = self.credentialProvider.clientCredential() else {
            throw Errors.couldNotObtainCredential
        }
        let endpoint = try TrashLinkEndpoint(parameters: parameters, service: service, credential: credential, breadcrumbs: breadcrumbs.collect())
        return try await request(endpoint)
    }

    // Legacy, todo when album / computer is released, this can be removed
    public func retoreTrashNode(shareID: ShareID, linkIDs: [LinkID]) async throws -> [PartialFailure] {
        let parameters = RestoreLinkEndpoint.Parameters(shareID: shareID, linkIDs: linkIDs)
        let endpoint = RestoreLinkEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.responses.compactMap(PartialFailure.init)
    }
}

public protocol CopyRepository {
    func copyLinkToVolume(parameters: CopyLinkToVolumeEndpoint.Parameters) async throws -> Link.LinkID
}

extension Client: CopyRepository {
    public func copyLinkToVolume(parameters: CopyLinkToVolumeEndpoint.Parameters) async throws -> Link.LinkID {
        let endpoint = CopyLinkToVolumeEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.linkID
    }
}

public protocol DriveChecklistDataSource {
    func getDriveChecklist() async throws -> DriveChecklistStatusResponse
}

extension Client: DriveChecklistDataSource {
    public func getDriveChecklist() async throws -> DriveChecklistStatusResponse {
        let endpoint = DriveChecklistEndpoint(service: service, credential: try credential())
        let response = try await request(endpoint)
        return DriveChecklistStatusResponse(from: response)
    }
}

public protocol DriveUserSettingsRemoteResource {
    func fetchUserSettings() async throws -> DriveUserSettingsResponse
}

extension Client: DriveUserSettingsRemoteResource {
    public func fetchUserSettings() async throws -> DriveUserSettingsResponse {
        let endpoint = GetDriveUserSettingsEndpoint(service: service, credential: try credential())
        let response = try await request(endpoint)
        return response
    }
}

public protocol UpdateB2BUserSettingsDataSource {
    func updateB2BUserSettings(to value: Bool) async throws
}

extension Client: UpdateB2BUserSettingsDataSource {
    public func updateB2BUserSettings(to value: Bool) async throws {
        let settings = DriveUserSettingsUpdateRequest(b2BPhotosEnabled: value)
        let endpoint = try PutDriveUserSettingsEndpoint(service: service, credential: try credential(), settings: settings)
        _ = try await request(endpoint)
    }
}
