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
import PDContacts
import PDCore
import PDClient

protocol InvitationUserHandler {
    func execute(parameters: InvitationInteractor.Parameters) async throws -> [InviteeInfo]
}

final class InvitationInteractor: InvitationUserHandler {
    private let contactsManager: ContactsManagerProtocol
    private let externalUserInviteHandler: ExternalUserInviteHandler
    private let internalUserInviteHandler: InternalUserInviteHandler
    private let sessionVault: SessionVault
    private let sessionDecryptor: SessionKeyDecryptionResource
    
    init(
        contactsManager: ContactsManagerProtocol,
        sessionDecryptor: SessionKeyDecryptionResource,
        externalUserInviteHandler: ExternalUserInviteHandler,
        internalUserInviteHandler: InternalUserInviteHandler,
        sessionVault: SessionVault
    ) {
        self.contactsManager = contactsManager
        self.sessionDecryptor = sessionDecryptor
        self.externalUserInviteHandler = externalUserInviteHandler
        self.internalUserInviteHandler = internalUserInviteHandler
        self.sessionVault = sessionVault
    }
    
    func execute(parameters: Parameters) async throws -> [InviteeInfo] {
        let mails = parameters.candidates.flatMap { $0.selectedMails }
        
        let signersKit = try sessionVault.make(forSigner: .address(parameters.share.creator))
        let sessionKey = try getSessionKey(from: signersKit, passphrase: parameters.share.passphrase)
        let emailDetail = generateEmailDetail(from: parameters)
        
        // Follow the web process.
        // When inviting multiple users, if an error occurs for any user, return the errors.
        // Do not clear the candidate list, even if some users have already been invited.
        let invitations = try await withThrowingTaskGroup(
            of: InviteeInfo?.self,
            returning: [InviteeInfo].self
        ) { [weak self] taskGroup in
            guard let self else { return [] }
            for email in mails {
                taskGroup.addTask {
                    try await self.invite(
                        parameters: .init(
                            email: email,
                            emailDetails: emailDetail,
                            permission: parameters.permission,
                            sessionKey: sessionKey,
                            share: parameters.share,
                            signersKit: signersKit
                        ),
                        hasSharingExternalInvitations: parameters.hasSharingExternalInvitations
                    )
                }
            }
            
            var invitations: [InviteeInfo] = []
            for try await result in taskGroup {
                if let result {
                    invitations.append(result)
                }
            }
            return invitations
        }
        return invitations
    }
    
    private func getSessionKey(from signersKit: SignersKit, passphrase: String) throws -> SessionKey {
        let decryptionKeys = signersKit.address.activeKeys.compactMap(KeyPair.init).map(\.decryptionKey)
        if decryptionKeys.isEmpty {
            throw SessionVault.Errors.addressHasNoActiveKeys
        }
        let sessionKey = try sessionDecryptor.shareSessionKey(
            sharePassphrase: passphrase,
            shareCreatorDecryptionKeys: decryptionKeys
        )
        return sessionKey
    }
}

extension InvitationInteractor {
    struct Parameters {
        let candidates: [ContactQueryResult]
        let hasSharingExternalInvitations: Bool
        let invitationMessage: String
        let isIncludingMessage: Bool
        let itemName: String
        let permission: AccessPermission
        let share: PDClient.Share
    }
    
    private struct InvitationParameters {
        let email: String
        let emailDetails: ShareInviteEmailDetails?
        let permission: AccessPermission
        let sessionKey: SessionKey
        let share: PDClient.Share
        let signersKit: SignersKit
    }
    
    private func generateEmailDetail(from parameters: Parameters) -> ShareInviteEmailDetails? {
        if parameters.isIncludingMessage {
            return .init(
                itemName: parameters.itemName,
                message: parameters.invitationMessage
            )
        } else {
            return nil
        }
    }
    
    private func invite(
        parameters: InvitationParameters,
        hasSharingExternalInvitations: Bool
    ) async throws -> InviteeInfo? {
        let keyRes = try? await contactsManager.fetchActivePublicKeys(email: parameters.email, internalOnly: true)
        // `Unverified` key:
        // These are legacy keys that were never migrated
        // For account signed up a really long time ago on web, or >2y ago on mobile, and has not used web for >3y
        //
        // If there are no other good key for the address, we should fallback to the unverified one
        let publicKey = keyRes?.address.keys.first?.publicKey ?? keyRes?.unverified?.keys.first?.publicKey
        
        guard let publicKey else {
            if hasSharingExternalInvitations {
                return try await inviteExternal(parameters: parameters)
            } else {
                return nil
            }
        }
        return try await inviteInternal(parameters: parameters, inviteePublicKey: publicKey)
    }
    
    private func inviteExternal(parameters: InvitationParameters) async throws -> ExternalInvitation? {
        try await externalUserInviteHandler.execute(
            parameters: .init(
                emailDetails: parameters.emailDetails,
                inviteeEmail: parameters.email,
                permission: parameters.permission,
                sessionKey: parameters.sessionKey,
                shareID: parameters.share.shareID,
                signersKit: parameters.signersKit
            )
        )
    }
    
    private func inviteInternal(parameters: InvitationParameters, inviteePublicKey: String) async throws -> ShareMemberInvitation? {
        try await internalUserInviteHandler.execute(
            parameters: .init(
                emailDetails: parameters.emailDetails,
                internalEmail: parameters.email,
                inviteePublicKey: inviteePublicKey,
                permission: parameters.permission,
                sessionKey: parameters.sessionKey,
                shareCreator: parameters.share.creator,
                shareID: parameters.share.shareID,
                signersKit: parameters.signersKit,
                externalInvitationID: nil
            )
        )
    }
}
