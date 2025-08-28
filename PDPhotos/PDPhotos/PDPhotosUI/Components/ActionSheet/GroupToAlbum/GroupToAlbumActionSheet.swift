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
import PDLocalization
import PDUIComponents
import PDCore

struct GroupToAlbumActionSheet: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    private let viewModel: GroupToAlbumActionSheetViewModel

    init(viewModel: GroupToAlbumActionSheetViewModel) {
        self.viewModel = viewModel
    }

    var bottomInset: CGFloat {
        if viewModel.canScroll { return 0 }
        return hostingProvider.viewController?.view.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                createAlbumButton
                separator
                    .padding(.horizontal, -16)
                VerticalAlbumList(
                    albumList: viewModel.albumList,
                    cellViewModel: { listing in viewModel.makeCellViewModel(for: listing) },
                    groupToAlbum: { identifier in
                        hostingProvider.viewController?.dismiss(animated: false)
                        viewModel.groupToAlbum(identifier: identifier)
                    }
                )
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: bottomInset)
            }
        }
        .frame(height: viewModel.sheetHeight + bottomInset)
        .scrollDisabled(!viewModel.canScroll)
    }

    private var createAlbumButton: some View {
        Button {
            hostingProvider.viewController?.dismiss(animated: false)
            viewModel.createAlbum(isCreatingSharedAlbum: false)
        } label: {
            HStack(spacing: 0) {
                IconProvider.plus
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(ColorProvider.IconNorm)
                    .padding(.leading, 7)
                    .padding(.trailing, 18)

                Text(Localization.action_add_to_new_album)
                    .modifier(ResizableTextModifier(font: .body, textColor: ColorProvider.TextNorm))
            }
        }
        .frame(height: 64)
        .accessibilityIdentifier("GroupToAlbumActionSheet.createAlbumButton")
    }

    private var separator: some View {
        Rectangle()
            .fill(ColorProvider.SeparatorNorm)
            .frame(height: 1)
    }
}
