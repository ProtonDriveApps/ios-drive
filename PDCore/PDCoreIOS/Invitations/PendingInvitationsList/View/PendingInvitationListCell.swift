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

import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

struct PendingInvitationListCell<ViewModel: PendingInvitationListCellViewModelProtocol>: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        content
            .foregroundColor(ColorProvider.BackgroundNorm)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var content: some View {
        if let state = vm.state {
            makeCellContent(state: state)
        } else {
            Rectangle()
        }
    }

    private func makeCellContent(state: PendingInvitationListCellViewState) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: .zero) {
                icon(asset: state.iconName, initialLetter: state.inviter)
                    .frame(width: 40, height: 40)
                    .padding(.trailing)

                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.title)
                            .truncationMode(.tail)
                            .foregroundColor(ColorProvider.TextNorm)
                            .lineLimit(1)
                            .accessibility(identifier: "PendingInvitationListCell.Text.\(state.title)")

                        Text(state.subtitle)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundColor(ColorProvider.TextWeak)
                    }
                }

                Spacer()
            }

            actionButtons(name: state.title)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    func icon(asset: FileAssetName, initialLetter: String) -> some View {
        ZStack(alignment: .bottomTrailing) {

            FileAssetImageProvider.icon(for: asset)
                .resizable()
                .frame(width: 32, height: 32, alignment: .leading)

            RoundedRectangle(cornerRadius: 8)
                .fill(ColorProvider.Shade40)
                .frame(width: 20, height: 20)
                .overlay(
                    Text(initialLetter)
                        .foregroundColor(ColorProvider.White)
                        .font(.system(size: 14, weight: .bold))
                )
                .offset(x: 5, y: 5)
        }
    }

    @ViewBuilder
    func actionButtons(name: String) -> some View {
        HStack(spacing: 12) {
            LoadingButton(action: vm.reject) {
                Text(Localization.pending_invitation_screen_decline)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .foregroundColor(ColorProvider.TextNorm)
                    .background(ColorProvider.InteractionWeak)
                    .cornerRadius(8)
            }
            .accessibilityIdentifier("PendingInvitationListCell.Decline.\(name)")

            LoadingButton(action: vm.accept) {
                Text(Localization.pending_invitation_screen_accept)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .foregroundColor(ColorProvider.TextInverted)
                    .background(ColorProvider.NotificationSuccess)
                    .cornerRadius(8)
            }
            .accessibilityIdentifier("PendingInvitationListCell.Accept.\(name)")
        }
    }
}
