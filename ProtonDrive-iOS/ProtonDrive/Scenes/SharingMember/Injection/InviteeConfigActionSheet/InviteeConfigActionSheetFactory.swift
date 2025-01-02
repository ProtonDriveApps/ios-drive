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
import ProtonCoreUIFoundations
import PDLocalization

struct InviteeConfigActionSheetFactory {
    let viewModel: InviteeConfigActionSheetViewModel

    func makeConfigActionSheet() -> PMActionSheet {
        var sheet: PMActionSheet!
        let header = makeActionHeader()
        let viewerAction = makeViewerAction {
            viewModel.update(permission: [.read])
            sheet.dismiss(animated: true)
            sheet = nil
        }
        let editorAction = makeEditorAction {
            viewModel.update(permission: [.read, .write])
            sheet.dismiss(animated: true)
            sheet = nil
        }
        let permissionGroup = PMActionSheetItemGroup(items: [viewerAction, editorAction], style: .singleSelection)
        let actionGroup = makeInviteeActionGroup()
        sheet = PMActionSheet(headerView: header, itemGroups: [permissionGroup, actionGroup])
        return sheet
    }
    
    private func makeActionHeader() -> PMActionSheetHeaderView {
        PMActionSheetHeaderView(
            title: viewModel.sheetHeaderTitle,
            subtitle: viewModel.sheetHeaderSubtitle,
            leftItem: .left(""),
            rightItem: .left(""), // Workaround to center-align the title.
            hasSeparator: true
        )
    }
    
    private func makeViewerAction(handler: @escaping () -> Void) -> PMActionSheetItem {
        PMActionSheetItem(
            style: .default(IconProvider.eye, viewModel.viewerActionTitle),
            hasSeparator: false,
            markType: viewModel.isEditor ? .none : .checkMark
        ) {_ in
            handler()
        }
    }
    
    private func makeEditorAction(handler: @escaping () -> Void) -> PMActionSheetItem {
         PMActionSheetItem(
            style: .default(IconProvider.pencil, viewModel.editorActionTitle),
            markType: viewModel.isEditor ? .checkMark : .none
         ) { _ in
             handler()
         }
    }
    
    private func makeInviteeActionGroup() -> PMActionSheetItemGroup {
        var actions: [PMActionSheetItem] = []
        if !viewModel.isInviteeAccept {
            let resendInviteAction = PMActionSheetItem(
                style: .default(IconProvider.paperPlaneHorizontal, Localization.sharing_member_resend_invite),
                hasSeparator: false
            ) { _ in
                viewModel.resendInvitationMail()
            }
            actions.append(resendInviteAction)
        }
        
        if viewModel.isInternal && !viewModel.isInviteeAccept {
            let copyLinkAction = PMActionSheetItem(
                style: .default(IconProvider.link, Localization.sharing_member_copy_invite_link),
                hasSeparator: false
            ) { _ in
                viewModel.copyInvitationLink()
            }
            actions.append(copyLinkAction)
        }

        let removeAccessAction = PMActionSheetItem(
            components: [
                PMActionSheetIconComponent(
                    icon: IconProvider.cross,
                    iconColor: ColorProvider.NotificationError,
                    edge: [nil, nil, nil, 16]
                ),
                PMActionSheetTextComponent(
                    text: .left(Localization.sharing_member_remove_access),
                    textColor: ColorProvider.NotificationError,
                    edge: [nil, 16, nil, 12]
                )
            ],
            hasSeparator: false
        ) { _ in
            viewModel.removeAccess()
        }
        actions.append(removeAccessAction)
        let actionGroup = PMActionSheetItemGroup(items: actions, style: .clickable)
        return actionGroup
    }
}
