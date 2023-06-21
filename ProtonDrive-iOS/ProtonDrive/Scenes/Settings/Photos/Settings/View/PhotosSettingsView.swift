// Copyright (c) 2023 Proton AG
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

import PDUIComponents
import ProtonCore_UIFoundations
import SwiftUI

struct PhotosSettingsView<ViewModel: PhotosSettingsViewModel>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            content
                .flatNavigationBar(viewModel.title, leading: EmptyView(), trailing: EmptyView())
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
    }

    @ViewBuilder
    private var content: some View {
        VStack {
            HStack {
                settingsRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Spacer()
        }
    }

    @ViewBuilder
    private var settingsRow: some View {
        Text(viewModel.title)
            .font(.body)
            .foregroundColor(ColorProvider.TextNorm)
        Spacer()
        Toggle("", isOn: .init(get: {
            viewModel.isEnabled
        }, set: { value in
            viewModel.setEnabled(value)
        }))
        .toggleStyle(SwitchToggleStyle(tint: ColorProvider.InteractionNorm))
    }
}
