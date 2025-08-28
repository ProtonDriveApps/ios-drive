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

import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct InviteeListView: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @ObservedObject private var viewModel: InviteeViewModel
    
    init(viewModel: InviteeViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isFetchingList {
                inviteButton
                    .padding(.top, 16)
            }
            if !viewModel.inviteeList.isEmpty {
                sectionHeader
            }
            if viewModel.isFetchingList {
                SpinnerTextView(text: "")
            } else {
                inviteeList
                    .padding(.leading, -4) // To align with other elements
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var sectionHeader: some View {
        Text(viewModel.sectionHeader)
            .modifier(TextModifier())
            .padding(.top, 28)
            .padding(.bottom, 8)
            .accessibilityIdentifier("InviteeList.sectionHeader")
    }
    
    private var inviteeList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.inviteeList, id: \.swiftUIID) { invitation in
                inviteeCell(invitation: invitation)
            }
        }
    }
    
    @ViewBuilder
    private func inviteeCell(invitation: InviteeInfo) -> some View {
        let info = viewModel.info(of: invitation)
        HStack(alignment: .top, spacing: 12) {
            inviteeAvatar(
                title: info.name ?? info.mail,
                isEditor: invitation.permissions.isEditor,
                isPending: invitation.externalInvitationState == .pending
            )
            
            VStack(spacing: 0) {
                if let name = info.name {
                    Text(name)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
                    Text(info.mail)
                        .modifier(TextModifier(fontSize: 13, textColor: ColorProvider.TextWeak))
                        .accessibilityIdentifier("inviteeCell.inviteeEmail.\(info.mail)")
                } else {
                    Text(info.mail)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
                        .accessibilityIdentifier("inviteeCell.inviteeEmail.\(info.mail)")
                }
                Text(info.status)
                    .modifier(TextModifier(fontSize: 13, textColor: ColorProvider.TextWeak))
                    .accessibilityIdentifier("inviteeCell.inviteeRole.\(info.mail).\(info.statusAccessibilityIdentifier)")
            }
            .frame(maxWidth: .infinity)
            if viewModel.hasSharingEditing {
                AvatarView(
                    config: .init(
                        avatarSize: .init(width: 48, height: 48),
                        content: .right(IconProvider.chevronDownFilled),
                        backgroundColor: .clear,
                        foregroundColor: ColorProvider.IconWeak,
                        iconSize: .init(width: 24, height: 24)
                    )
                )
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle()) // To enable tap gesture
        .onTapGesture {
            UIApplication.shared.endEditing()
            if viewModel.hasSharingEditing {
                viewModel.presentConfigSheet(for: invitation, name: info.name)
            }
        }
    }
    
    @ViewBuilder
    private func inviteeAvatar(title: String, isEditor: Bool, isPending: Bool) -> some View {
        let icon: UIImage = isEditor ? IconProvider.pencil : IconProvider.eye
        let background: Color = isPending ? ColorProvider.IconHint : ColorProvider.IconAccent
        ZStack {
            AvatarView(
                config: .init(
                    avatarSize: .init(width: 40, height: 40),
                    content: .left(title),
                    cornerRadius: .extraHuge,
                    backgroundColor: ColorProvider.BackgroundSecondary
                )
            )
            
            AvatarView(
                config: .init(
                    avatarSize: .init(width: 20, height: 20),
                    content: .right(icon),
                    cornerRadius: .circled, 
                    backgroundColor: background,
                    foregroundColor: .white,
                    iconSize: .init(width: 12, height: 12)
                )
            )
            .padding(.leading, 23)
            .padding(.top, 23)
        }
    }
    
    private var inviteButton: some View {
        HStack(spacing: 12) {
            AvatarView(
                config: .init(
                    content: .right(IconProvider.userPlus),
                    backgroundColor: ColorProvider.BackgroundSecondary
                )
            )
            Text(viewModel.inviteButtonTitle)
                .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
                .accessibilityIdentifier("InviteeListView.inviteButtonLabel")
        }
        .frame(height: 64)
        .contentShape(Rectangle()) // To enable tap gesture
        .onTapGesture {
            UIApplication.shared.endEditing()
            viewModel.clickInviteButton()
        }
    }
}
