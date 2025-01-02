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
import PDLocalization

enum InvitationErrors: Error {
    /// Empty shareID, invitationID...etc
    case unexpectedData
    case alreadyInvited
    // the invitation does not exist, is not pending or rejected
    case noExists
    // the current user does not have admin permission on this share
    case notAllowed
    case missingInviteeAddressOrKey
    case groupNotYetSupported
    case invalidInviterAddress
    case temporarilyDisabled
    case invitedWithDifferentEmail
    case invalidKeyPacket
    case invalidKeyPacketSignature
    case invalidAddress
    case insufficientInvitationQuota
    case insufficientShareJoinedQuota
    
    /// Error code collects from API document
    var code: Int {
        switch self {
        case .unexpectedData:
            return -999
        case .missingInviteeAddressOrKey:
            return 2000
        case .invalidAddress:
            return 2001
        case .invalidInviterAddress:
            return 2008
        case .alreadyInvited:
            return 2500
        case .noExists:
            return 2501
        case .notAllowed:
            return 2011
        case .temporarilyDisabled:
            return 2032
        case .invitedWithDifferentEmail:
            return 200201
        case .groupNotYetSupported:
            return 200202
        case .invalidKeyPacket:
            return 200501
        case .invalidKeyPacketSignature:
            return 200502
        case .insufficientInvitationQuota:
            return 200600
        case .insufficientShareJoinedQuota:
            return 200602
        }
    }
    
    init?(code: Int) {
        switch code {
        case InvitationErrors.alreadyInvited.code:
            self = .alreadyInvited
        case InvitationErrors.noExists.code:
            self = .noExists
        case InvitationErrors.notAllowed.code, 2026:
            // 2026, trying to grant permissions you do not have to a new member
            self = .notAllowed
        case InvitationErrors.missingInviteeAddressOrKey.code:
            self = .missingInviteeAddressOrKey
        case InvitationErrors.invalidInviterAddress.code:
            self = .invalidInviterAddress
        case InvitationErrors.temporarilyDisabled.code:
            self = .temporarilyDisabled
        case InvitationErrors.invitedWithDifferentEmail.code:
            self = .invitedWithDifferentEmail
        case InvitationErrors.groupNotYetSupported.code:
            self = .groupNotYetSupported
        case InvitationErrors.invalidKeyPacket.code:
            self = .invalidKeyPacket
        case InvitationErrors.invalidKeyPacketSignature.code:
            self = .invalidKeyPacketSignature
        case InvitationErrors.insufficientInvitationQuota.code:
            self = .insufficientInvitationQuota
        case InvitationErrors.insufficientShareJoinedQuota.code:
            self = .insufficientShareJoinedQuota
        case InvitationErrors.invalidAddress.code:
            self = .invalidAddress
        default:
            return nil
        }
    }
}

extension InvitationErrors: LocalizedError {
    /// User friendly localized message
    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return nil
        case .alreadyInvited:
            return Localization.sharing_member_error_already_invited
        case .noExists:
            return Localization.sharing_member_error_not_exist
        case .notAllowed:
            return Localization.sharing_member_error_not_allowed
        case .missingInviteeAddressOrKey:
            return Localization.sharing_member_error_missing_key
        case .groupNotYetSupported:
            return Localization.sharing_member_error_group_not_support
        case .invalidInviterAddress:
            return Localization.sharing_member_error_invalid_inviter_address
        case .temporarilyDisabled:
            return Localization.sharing_member_error_temporarily_disabled
        case .invitedWithDifferentEmail:
            return Localization.sharing_member_error_invited_with_different_email
        case .invalidKeyPacket:
            return Localization.sharing_member_error_invalid_key_packet
        case .invalidKeyPacketSignature:
            return Localization.sharing_member_error_invalid_key_packet_signature
        case .invalidAddress:
            return Localization.sharing_member_error_invalid_address
        case .insufficientInvitationQuota:
            return Localization.sharing_member_error_insufficient_invitation_quota
        case .insufficientShareJoinedQuota:
            return Localization.sharing_member_error_insufficient_share_joined_quota
        }
    }
}
