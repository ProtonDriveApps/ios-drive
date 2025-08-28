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

import SwiftUI
import ProtonCoreUIFoundations

struct AlbumDetailInfoView: View {
    @ObservedObject private var viewModel: AlbumDetailInfoViewModel
    private var isAddingPhotos: Bool

    init(viewModel: AlbumDetailInfoViewModel, isAddingPhotos: Bool) {
        self.viewModel = viewModel
        self.isAddingPhotos = isAddingPhotos
    }

    var body: some View {
        VStack(spacing: 0) {
            detailTopBar
                .frame(height: 24)
                .padding(.top, 21)
            titleRow
                .padding(.top, 8)
            if !viewModel.configuration.isPickingPhotos {
                actionRow
                    .padding(.top, 20)
            }
        }
    }

    private var detailTopBar: some View {
        HStack {
            Text(viewModel.info)
                .foregroundStyle(ColorProvider.TextHint)
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
            if !viewModel.invitationList.isEmpty {
                ShareMemberRow(userList: viewModel.invitationList)
                    .onTapGesture {
                        viewModel.tapShare()
                    }
            }
        }
        .accessibilityIdentifier("AlbumDetailView.detailTopBar")
    }

    private var titleRow: some View {
        Text(viewModel.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.title)
            .fontWeight(.bold)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .truncationMode(.tail)
            .accessibilityIdentifier("AlbumDetailView.TitleRow.\(viewModel.title)")
    }

    private var actionRow: some View {
        HStack {
            if viewModel.canAddPhotos {
                ActionButton(
                    title: AlbumDetailConstants.add,
                    icon: IconProvider.plusCircleFilled,
                    foregroundColor: ColorProvider.TextNorm,
                    backgroundColor: InternalColor.buttonBackgroundNorm,
                    isLoading: .init(get: { isAddingPhotos }, set: { _ in })
                ) {
                    viewModel.tapAdd()
                }
                .disabled(isAddingPhotos)
                .accessibilityIdentifier("AlbumDetailView.ActionButton.Add")
            }

            if viewModel.isSharingAvailable {
                ActionButton(
                    title: AlbumDetailConstants.share,
                    icon: InternalIcon.userPlusFilled,
                    foregroundColor: InternalColor.shareButtonForeground,
                    backgroundColor: InternalColor.shareButtonBackground
                ) {
                    viewModel.tapShare()
                }
                .accessibilityIdentifier("AlbumDetailView.ActionButton.Share")
            }

            viewModel.saveAllButton.map { title in
                ActionButton(
                    title: title,
                    icon: InternalIcon.cloudArrowDown,
                    foregroundColor: ColorProvider.TextNorm,
                    backgroundColor: InternalColor.buttonBackgroundNorm,
                    isLoading: .init(get: { viewModel.isSaveAllLoading }, set: { _ in })
                ) {
                    viewModel.tapSaveAll()
                }
                .disabled(viewModel.isSaveAllLoading)
                .accessibilityIdentifier("AlbumDetailView.ActionButton.SaveAll")
            }
            Spacer()
        }
    }
}
