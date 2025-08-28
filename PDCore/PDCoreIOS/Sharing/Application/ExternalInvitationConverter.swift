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
import PDCore
import PDContacts

/// Convert external invitation to internal invitation after getting invitee signup event
public final class ExternalInvitationConverter: ExternalInvitationConvertProtocol {
    private let client: ShareClient
    private let contactsManager: ContactsManagerProtocol
    private let inviteHandler: InternalUserInviteHandler
    private let sessionDecryptor: SessionKeyDecryptionResource
    private let signersFactory: SignersKitFactoryProtocol

    public init(
        client: ShareClient,
        contactsManager: ContactsManagerProtocol,
        inviteHandler: InternalUserInviteHandler,
        sessionDecryptor: SessionKeyDecryptionResource = SessionKeyDecryptor(),
        signersFactory: SignersKitFactoryProtocol
    ) {
        self.client = client
        self.contactsManager = contactsManager
        self.inviteHandler = inviteHandler
        self.sessionDecryptor = sessionDecryptor
        self.signersFactory = signersFactory
    }

    public func execute(parameters: ExternalInvitationConvertParameters) async throws {
        guard let invitation = try await fetchExternalInvitation(client: client, parameters: parameters) else {
            return
        }
        let share = try await client.getMetadata(forShare: parameters.shareID)
        guard let signersKit = try? signersFactory.make(forSigner: .address(invitation.inviterEmail)) else {
            return
        }
        guard let publicKey = await fetchPublicKey(mail: invitation.inviteeEmail) else {
            Log.warning("Public key is nil", domain: .sharing)
            return
        }
        let sessionKey = try getSessionKey(from: signersKit, passphrase: share.passphrase)
        _ = try await inviteHandler.execute(
            parameters: .init(
                emailDetails: nil,
                internalEmail: invitation.inviteeEmail,
                inviteePublicKey: publicKey,
                permission: invitation.permissions,
                sessionKey: sessionKey,
                shareCreator: invitation.inviterEmail,
                shareID: parameters.shareID,
                signersKit: signersKit,
                externalInvitationID: parameters.externalInvitationID
            )
        )
    }

    private func fetchExternalInvitation(
        client: ShareInvitationAPIClient,
        parameters: ExternalInvitationConvertParameters
    ) async throws -> ExternalInvitation? {
        let invitations = try await client.listExternalInvitations(shareID: parameters.shareID)
        guard
            let invitation = invitations.first(where: { $0.externalInvitationID == parameters.externalInvitationID })
        else{
            Log.debug("Can't find the external invitation", domain: .sharing)
            return nil
        }
        return invitation
    }

    private func fetchPublicKey(mail: String) async -> String? {
        let keyRes = try? await contactsManager.fetchActivePublicKeys(email: mail, internalOnly: true)
        // `Unverified` key:
        // These are legacy keys that were never migrated
        // For account signed up a really long time ago on web, or >2y ago on mobile, and has not used web for >3y
        //
        // If there are no other good key for the address, we should fallback to the unverified one
        let publicKey = keyRes?.address.keys.first?.publicKey ?? keyRes?.unverified?.keys.first?.publicKey
        return publicKey
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
