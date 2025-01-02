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
import PDCore
import PDClient

protocol InternalUserInviteHandler {
    func execute(parameters: InternalUserInviteInteractor.Parameters) async throws -> ShareMemberInvitation?
}

final class InternalUserInviteInteractor: InternalUserInviteHandler {
    static let signatureContext = "drive.share-member.inviter"
    private let client: ShareInvitationAPIClient
    private let encryptor: EncryptionResource
    
    init(client: ShareInvitationAPIClient, encryptionResource: EncryptionResource) {
        self.client = client
        self.encryptor = encryptionResource
    }
    
    func execute(parameters: Parameters) async throws -> ShareMemberInvitation? {
        assert(!parameters.shareID.isEmpty)
        if parameters.shareID.isEmpty { return nil }
        
        let keyPacket = try encryptor.encryptSessionKey(
            sessionKey: parameters.sessionKey,
            with: parameters.inviteePublicKey
        )
        
        let signature = try encryptor.sign(
            keyPacket,
            context: Self.signatureContext,
            privateKey: parameters.signersKit.addressKey.privateKey,
            passphrase: parameters.signersKit.addressPassphrase
        )
        
        do {
            let invitation = try await client.inviteProtonUser(
                shareID: parameters.shareID,
                body: .init(
                    emailDetails: parameters.emailDetails,
                    invitation: .init(
                        inviteeEmail: parameters.internalEmail,
                        inviterEmail: parameters.shareCreator,
                        keyPacket: keyPacket.encodeBase64(),
                        keyPacketSignature: signature.encodeBase64(),
                        permissions: parameters.permission
                    )
                )
            )
            return invitation
        } catch {
            if let code = error.responseCode, code == InvitationErrors.alreadyInvited.code {
                return nil
            }
            throw error
        }
    }
}

extension InternalUserInviteInteractor {
    struct Parameters {
        let emailDetails: ShareInviteEmailDetails?
        let internalEmail: String
        let inviteePublicKey: String
        let permission: AccessPermission
        let sessionKey: SessionKey
        let shareCreator: String
        let shareID: String
        let signersKit: SignersKit
    }
}
