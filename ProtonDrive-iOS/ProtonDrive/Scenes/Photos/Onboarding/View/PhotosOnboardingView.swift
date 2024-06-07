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

struct PhotosOnboardingView: View {
    private let viewModel: PhotosOnboardingViewModelProtocol

    init(viewModel: PhotosOnboardingViewModelProtocol) {
        self.viewModel = viewModel
    }

    var body: some View {
        makeContent(with: viewModel.data)
    }

    private func makeContent(with data: PhotosOnboardingViewData) -> some View {
        VStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .center, spacing: 16) {
                        Image("photos_onboarding")
                        Text(data.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ColorProvider.TextNorm)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("PhotosOnboardingView.headline")
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(data.rows) { row in
                            PhotosOnboardingRowView(row: row)
                        }
                    }
                }
            }
            Spacer(minLength: 24)
            BlueRectButton(title: data.button, cornerRadius: .huge, action: viewModel.enableBackup)
                .accessibilityIdentifier("PhotosOnboardingView.enableBackupButton")
        }
        .padding(24)
        .background(ColorProvider.BackgroundNorm)
    }
}
