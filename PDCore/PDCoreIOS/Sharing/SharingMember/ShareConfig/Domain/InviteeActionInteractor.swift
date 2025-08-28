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
import PDCore

protocol InviteeActionHandler {
    func removeAccess(of invitation: InviteeInfo, shareID: String, isLast: Bool) async throws
    func resendInvitations(to invitation: InviteeInfo, shareID: String) async throws
    func copyInvitationLink(invitation: InviteeInfo, volumeID: String, linkID: String) async throws -> String?
    func update(permission: AccessPermission, for invitation: InviteeInfo, shareID: String) async throws -> InviteeInfo
}

final class InviteeActionInteractor: InviteeActionHandler {
    private let client: ShareInvitationAPIClient & ShareMemberAPIClient
    private let linkAssemblePolicy: InvitationLinkAssemblePolicyProtocol
    private let shareDeleter: ShareDeleter

    init(
        client: ShareInvitationAPIClient & ShareMemberAPIClient,
        linkAssemblePolicy: InvitationLinkAssemblePolicyProtocol,
        shareDeleter: ShareDeleter
    ) {
        self.client = client
        self.linkAssemblePolicy = linkAssemblePolicy
        self.shareDeleter = shareDeleter
    }
    
    func removeAccess(of invitation: InviteeInfo, shareID: String, isLast: Bool) async throws {
        if shareID.isEmpty || invitation.invitationID.isEmpty {
            throw InvitationErrors.unexpectedData
        }

        if invitation.isInviteeAccept {
            try await client.removeMember(shareID: shareID, memberID: invitation.invitationID)
        } else if invitation.isInternal {
            try await client.deleteInvitation(shareID: shareID, invitationID: invitation.invitationID)
        } else {
            try await client.deleteExternalInvitation(shareID: shareID, invitationID: invitation.invitationID)
        }

        // Try soft deleting the share. Will fail if there are more members & invitations etc on BE
        if isLast {
            try? await shareDeleter.deleteShare(shareID, force: false)
        }
    }
    
    func resendInvitations(to invitation: InviteeInfo, shareID: String) async throws {
        if shareID.isEmpty || invitation.invitationID.isEmpty {
            throw InvitationErrors.unexpectedData
        }

        if invitation.isInternal {
            try await client.resendInvitationEmail(shareID: shareID, invitationID: invitation.invitationID)
        } else {
            try await client.resendExternalInvitationEmail(shareID: shareID, invitationID: invitation.invitationID)
        }
    }
    
    /// - Returns: link
    func copyInvitationLink(invitation: InviteeInfo, volumeID: String, linkID: String) async throws -> String? {
        // Only internal invitation has invitation link
        guard invitation.isInternal else { return nil }

        let parameters = InvitationLinkAssembleParameters(
            volumeID: volumeID,
            linkID: linkID,
            invitationID: invitation.invitationID,
            inviteeEmail: invitation.inviteeEmail
        )

        guard let url = linkAssemblePolicy.assembleLink(parameters: parameters) else {
            Log.error("Assemble invitation link failed", error: nil, domain: .sharing)
            return nil
        }
        return url.absoluteString
    }
    
    func update(
        permission: AccessPermission,
        for invitation: InviteeInfo,
        shareID: String
    ) async throws -> InviteeInfo {
        if shareID.isEmpty || invitation.invitationID.isEmpty {
            throw InvitationErrors.unexpectedData
        }
        
        if permission == invitation.permissions { return invitation }
        if invitation.isInviteeAccept {
            return try await updateMember(permission: permission, for: invitation, shareID: shareID)
        } else if invitation.isInternal {
            return try await updateInternal(permission: permission, for: invitation, shareID: shareID)
        } else {
            return try await updateExternal(permission: permission, for: invitation, shareID: shareID)
        }
    }
    
    private func updateMember(
        permission: AccessPermission,
        for member: InviteeInfo,
        shareID: String
    ) async throws -> InviteeInfo {
        guard let existing = member as? ShareMember else {
            throw InvitationErrors.unexpectedData
        }
        try await client.updateShareMemberPermissions(
            shareID: shareID,
            memberID: existing.memberID,
            permissions: permission
        )
        let newMember = ShareMember(
            createTime: existing.createTime,
            email: existing.email,
            inviterEmail: existing.inviterEmail,
            keyPacket: existing.keyPacket,
            keyPacketSignature: existing.keyPacketSignature,
            memberID: existing.memberID,
            permissions: permission,
            sessionKeySignature: existing.sessionKeySignature
        )
        return newMember
    }
    
    private func updateInternal(
        permission: AccessPermission,
        for invitation: InviteeInfo,
        shareID: String
    ) async throws -> InviteeInfo {
        guard let existing = invitation as? ShareMemberInvitation else {
            throw InvitationErrors.unexpectedData
        }
        try await client.updateInvitationPermissions(
            shareID: shareID,
            invitationID: invitation.invitationID,
            permissions: permission
        )
        let newInvitation = ShareMemberInvitation(
            invitationID: invitation.invitationID,
            inviterEmail: existing.inviterEmail,
            inviteeEmail: existing.inviteeEmail,
            permissions: permission,
            keyPacket: existing.keyPacket,
            keyPacketSignature: existing.keyPacketSignature,
            createTime: existing.createTime
        )
        return newInvitation
    }
    
    private func updateExternal(
        permission: AccessPermission,
        for invitation: InviteeInfo,
        shareID: String
    ) async throws -> InviteeInfo {
        guard let existing = invitation as? ExternalInvitation else {
            throw InvitationErrors.unexpectedData
        }
        try await client.updateExternalInvitationPermissions(
            shareID: shareID,
            invitationID: invitation.invitationID,
            permissions: permission
        )
        let newInvitation = ExternalInvitation(
            externalInvitationID: invitation.invitationID,
            inviterEmail: existing.inviterEmail,
            inviteeEmail: existing.inviteeEmail,
            permissions: permission,
            externalInvitationSignature: existing.externalInvitationSignature,
            state: existing.state,
            createTime: existing.createTime
        )
        return newInvitation
    }
}
