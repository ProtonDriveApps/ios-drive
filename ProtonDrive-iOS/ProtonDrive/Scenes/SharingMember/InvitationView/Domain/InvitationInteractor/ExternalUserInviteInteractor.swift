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

protocol ExternalUserInviteHandler {
    func execute(parameters: ExternalUserInviteParameters) async throws -> ExternalInvitation?
}

final class ExternalUserInviteInteractor: ExternalUserInviteHandler {
    static let signatureContext = "drive.share-member.external-invitation"
    private let client: ShareInvitationAPIClient
    private let encryptionResource: EncryptionResource
    
    init(client: ShareInvitationAPIClient, encryptionResource: EncryptionResource) {
        self.client = client
        self.encryptionResource = encryptionResource
    }
    
    func execute(parameters: ExternalUserInviteParameters) async throws -> ExternalInvitation? {
        do {
            let body = try makeRequestBody(parameters: parameters)
            let invitation = try await client.inviteExternalUser(
                shareID: parameters.shareID,
                body: body
            )
            return invitation
        } catch {
            if let code = error.responseCode, code == InvitationErrors.alreadyInvited.code {
                return nil
            }
            throw error
        }
    }
    
    private func makeRequestBody(
        parameters: ExternalUserInviteParameters
    ) throws -> InviteExternalUserEndpoint.Parameters.Body {
        let text = "\(parameters.inviteeEmail)|\(parameters.sessionKey.encodeBase64())"
        let signature = try encryptionResource.sign(
            text: text,
            context: Self.signatureContext,
            privateKey: parameters.signersKit.addressKey.privateKey,
            passphrase: parameters.signersKit.addressPassphrase
        )
        
        return .init(
            externalInvitation: .init(
                inviterAddressID: parameters.signersKit.address.addressID,
                inviteeEmail: parameters.inviteeEmail,
                permissions: parameters.permission,
                ExternalInvitationSignature: signature.encodeBase64()
            ),
            emailDetails: parameters.emailDetails
        )
    }
}

struct ExternalUserInviteParameters {
    let emailDetails: ShareInviteEmailDetails?
    let inviteeEmail: String
    let permission: AccessPermission
    let sessionKey: SessionKey
    let shareID: String
    let signersKit: SignersKit
}
