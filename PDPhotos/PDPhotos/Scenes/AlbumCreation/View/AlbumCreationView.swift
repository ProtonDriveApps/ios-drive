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

struct AlbumCreationView: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var nameFocus: Bool
    @State private var hasFocused = false
    @ObservedObject var viewModel: AlbumCreationViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                textArea
                    .padding(.vertical, 26)
                addButton
                gridView
                Spacer()

                if viewModel.isSelecting {
                    removeButton(width: geometry.size.width)
                        .padding(.horizontal, -20)
                }
            }
            .onAppear {
                if !hasFocused {
                    hasFocused = true
                    nameFocus = true
                }
            }
            .disabled(viewModel.isProcessing)
            .padding(.horizontal, 20)
            .toolbar {
                doneButton
            }
        }
        .background(ColorProvider.BackgroundNorm)
    }

    private var textArea: some View {
        TextField(Localization.create_album_placeholder, text: $viewModel.albumName)
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(ColorProvider.TextNorm)
            .accessibilityIdentifier("AlbumCreationView.TextField.Create_album_placeholder")
            .focused($nameFocus)
    }

    private var addButton: some View {
        HStack {
            ActionButton(
                title: Localization.general_add,
                icon: IconProvider.plusCircleFilled,
                foregroundColor: ColorProvider.TextNorm,
                backgroundColor: InternalColor.buttonBackgroundNorm
            ) { [weak viewModel] in
                viewModel?.tapAddButton()
            }

            Spacer()
        }
        .accessibilityIdentifier("AlbumCreationView.ActionButton.AddButton")
    }

    private var gridView: some View {
        VGridView(
            viewModel: viewModel.photosViewModel,
            configuration: .photosInAlbum()
        ) { item, idx in
            PhotoItemWrapperView {
                let viewModel = viewModel.makeItemViewModel(from: item as! PhotoGridViewItem)
                return PhotoItemView(viewModel: viewModel, accessibilityIndex: "\(idx)")
            }
        }
    }

    @ViewBuilder
    private func removeButton(width: CGFloat) -> some View {
        Button {
            viewModel.tapRemovePhotos()
        } label: {
            Text(Localization.action_remove_photos)
                .foregroundStyle(ColorProvider.NotificationError)
                .font(.body)
                .frame(width: width, height: 56)
        }
    }

    @ToolbarContentBuilder
    var doneButton: some ToolbarContent {
        let color: Color = viewModel.canBeSaved ? ColorProvider.TextAccent : ColorProvider.TextAccent.opacity(0.6)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.tapDone()
            } label: {
                if viewModel.isProcessing {
                    ProtonSpinner(size: .small)
                } else {
                    Text(Localization.general_done)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
            }
            .disabled(!viewModel.canBeSaved)
            .accessibilityIdentifier("AlbumCreationView.ActionButton.DoneButton")
        }
    }
}
