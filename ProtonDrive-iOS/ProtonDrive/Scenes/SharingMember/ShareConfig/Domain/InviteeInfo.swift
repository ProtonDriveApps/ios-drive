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

protocol InviteeInfo {
    var createTime: Date { get }
    var invitationID: String { get }
    var inviteeEmail: String { get }
    var permissions: AccessPermission { get }
    var isInternal: Bool { get }
    var externalInvitationState: ExternalInviteState? { get }
    var isInviteeAccept: Bool { get }
}

extension ShareMemberInvitation: InviteeInfo {
    var externalInvitationState: PDClient.ExternalInviteState? { nil }
    var isInternal: Bool { true }
    var isInviteeAccept: Bool { false }
}

extension ExternalInvitation: InviteeInfo {
    var invitationID: String { externalInvitationID }
    var externalInvitationState: PDClient.ExternalInviteState? { state }
    var isInternal: Bool { false }
    var isInviteeAccept: Bool { false }
}

extension ShareMember: InviteeInfo {
    var invitationID: String { memberID }
    var inviteeEmail: String { email }
    var isInternal: Bool { true }
    var externalInvitationState: PDClient.ExternalInviteState? { nil }
    var isInviteeAccept: Bool { true }
}
