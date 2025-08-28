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
import PDLocalization

struct InviteeConfigActionSheetViewModel {
    let isEditor: Bool
    private let invitee: InviteeInfo
    private let inviteeName: String?
    private let isPending: Bool
    private weak var handler: InviteeConfigSheetViewModel?
    
    init(invitee: InviteeInfo, inviteeName: String?, handler: InviteeConfigSheetViewModel) {
        self.invitee = invitee
        self.inviteeName = inviteeName
        self.handler = handler
        
        self.isEditor = invitee.permissions.contains([.read, .write])
        self.isPending = invitee.externalInvitationState == .pending
    }
    
    var isInternal: Bool { invitee.isInternal }
    var isInviteeAccept: Bool { invitee.isInviteeAccept }
    
    var sheetHeaderTitle: String {
        if let inviteeName {
            return inviteeName.isEmpty ? invitee.inviteeEmail : inviteeName
        }
        return invitee.inviteeEmail
    }
    
    var sheetHeaderSubtitle: String? {
        if let inviteeName {
            return inviteeName.isEmpty ? nil : invitee.inviteeEmail
        } else {
            return nil
        }
    }
    
    var viewerActionTitle: String {
        let title = Localization.sharing_member_role_viewer
        guard isPending, !isEditor  else { return title }
        return "\(title) (\(Localization.sharing_member_pending))"
    }
    
    var editorActionTitle: String {
        let title = Localization.sharing_member_role_editor
        guard isPending, isEditor  else { return title }
        return "\(title) (\(Localization.sharing_member_pending))"
    }
    
    func update(permission: AccessPermission) {
        handler?.update(permission: permission, for: invitee)
    }
    
    func copyInvitationLink() {
        handler?.copyInvitationLink(invitee: invitee)
    }
    
    func removeAccess() {
        handler?.removeAccess(of: invitee)
    }
    
    func resendInvitationMail() {
        handler?.resendInvitationMail(to: invitee)
    }
}
