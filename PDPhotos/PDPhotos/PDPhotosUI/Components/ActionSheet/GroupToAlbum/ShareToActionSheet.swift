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
import PDUIComponents
import PDLocalization
import ProtonCoreUIFoundations
import PDCore

struct ShareToActionSheet: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    private let viewModel: GroupToAlbumActionSheetViewModel

    init(viewModel: GroupToAlbumActionSheetViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            shareSection
            VStack(spacing: 0) {
                sectionHeader(title: Localization.section_add_to_shared_album)
                VerticalAlbumList(
                    albumList: viewModel.albumList,
                    cellViewModel: { listing in viewModel.makeCellViewModel(for: listing) },
                    groupToAlbum: { identifier in
                        hostingProvider.viewController?.dismiss(animated: false)
                        viewModel.groupToAlbum(identifier: identifier)
                    }
                )
            }
        }
        .frame(height: viewModel.sheetHeight)
        .scrollDisabled(!viewModel.canScroll)
    }

    private var shareSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: Localization.section_share_via)

            actionButton(
                icon: IconProvider.users,
                title: Localization.action_new_shared_album
            ) {
                viewModel.createAlbum(isCreatingSharedAlbum: true)
            }
            .accessibilityIdentifier("ShareToActionSheet.newSharedAlbumButton")

            if viewModel.isSingleSelection {
                actionButton(
                    icon: IconProvider.userPlus,
                    title: Localization.action_send_link
                ) {
                    viewModel.shareViaLink()
                }
                .accessibilityIdentifier("ShareToActionSheet.sendLinkButton")

                actionButton(
                    icon: IconProvider.threeDotsHorizontal,
                    title: Localization.menu_section_title_more
                ) {
                    viewModel.nativeShare()
                }
                .accessibilityIdentifier("ShareToActionSheet.nativeShareButton")
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            Text(title)
                .modifier(ResizableTextModifier(font: .headline, textColor: ColorProvider.TextWeak))
            Spacer().frame(height: 8)
        }
    }

    private func actionButton(icon: Image, title: String, action: @escaping () -> Void) -> some View {
        Button {
            hostingProvider.viewController?.dismiss(animated: false)
            action()
        } label: {
            HStack(spacing: 0) {
                icon
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(ColorProvider.IconNorm)
                    .padding(.leading, 6)

                Text(title)
                    .modifier(ResizableTextModifier(font: .body, textColor: ColorProvider.TextNorm))
                    .padding(.horizontal, 18)
            }
            .frame(height: 64)
        }

    }
}
