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
import PDUIComponents

struct AlbumInvitationsView<ViewModel: AlbumInvitationsViewModel>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content
            .onAppear(perform: viewModel.onAppear)
    }

    @ViewBuilder
    private var content: some View {
        if let text = viewModel.text {
            makeView(text: text)
        } else {
            // Intentionally not using empty view, otherwise `onAppear` isn't triggered
            Spacer().frame(height: 0)
        }
    }

    private func makeView(text: String) -> some View {
        Button(action: viewModel.open) {
            InvitationsStatusBannerView(text: text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }
}
