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

struct AlbumRenameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var viewModel: AlbumRenameViewModel
    @FocusState private var isFocused: Bool

    init(viewModel: AlbumRenameViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("", text: $viewModel.name)
                        .frame(height: 86)
                        .font(.title2)
                        .foregroundStyle(ColorProvider.TextNorm)
                        .background(.clear)
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .padding(.horizontal, 16)
                        .focused($isFocused)
                        .accessibilityIdentifier("AlbumRenameView.renameAlbumTextField")
                }
                .frame(height: 86)
                .background(ColorProvider.BackgroundNorm)
                .padding(.top, 38)
                Spacer()
            }
            .background(ColorProvider.BackgroundSecondary)
            .navigationTitle(Localization.title_rename_album)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                closeButton
                doneButton
            }
            .disabled(viewModel.isProcessing)
        }
        .onAppear {
            isFocused = true
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    @ToolbarContentBuilder
    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                IconProvider.cross
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(ColorProvider.IconNorm)
                    .accessibilityIdentifier("AlbumRenameView.closeButton")
            }
        }
    }

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        let color: Color = viewModel.canBeSaved ? ColorProvider.TextAccent : ColorProvider.TextAccent.opacity(0.6)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.tapDone {
                    self.dismiss()
                }
            } label: {
                if viewModel.isProcessing {
                    ProtonSpinner(size: .small)
                } else {
                    Text(Localization.general_done)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .accessibilityIdentifier("AlbumRenameView.doneButton")
                }
            }
            .disabled(!viewModel.canBeSaved)
        }
    }
}
