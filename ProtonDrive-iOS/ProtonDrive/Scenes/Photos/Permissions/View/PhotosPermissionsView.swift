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

import ProtonCoreUIFoundations
import PDUIComponents
import SwiftUI

struct PhotosPermissionsView<ViewModel: PhotosPermissionsViewModelProtocol>: View {
    private let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            ScrollView {
                VStack(spacing: 0) {
                    Image("illustration_allPhotos")
                    Spacer(minLength: 24)
                    Text(viewModel.viewData.headline)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ColorProvider.TextNorm)
                        .accessibilityIdentifier("PhotosPermissionsView.headline")
                    Spacer(minLength: 12)
                    Text(viewModel.viewData.text)
                        .font(.body)
                        .foregroundColor(ColorProvider.TextWeak)
                        .accessibilityIdentifier("PhotosPermissionsView.text")
                }
                .padding(24)
            }
            BlueRectButton(title: viewModel.viewData.button, cornerRadius: .huge, action: viewModel.openSettings)
                .padding(24)
                .accessibilityIdentifier("PhotosPermissionsView.allowButton")
        }
        .multilineTextAlignment(.center)
    }
}
