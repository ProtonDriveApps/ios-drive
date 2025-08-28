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
        // Disabled new style illustration until marketing updates the screens.
        makeOldContent(with: viewModel.data)
//        GeometryReader { proxy in
//            makeNewContent(with: viewModel.data, width: proxy.size.width)
//        }
    }

    private func makeNewContent(with data: PhotosOnboardingViewData, width: Double) -> some View {
        VStack(alignment: .center) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 0) {
                        Spacer(minLength: 0)
                        InternalIcon.photosOnboarding
                            .resizable()
                            .scaledToFill()
                            .frame(width: min(width, 521), height: 274)
                            .clipped()
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Text(data.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ColorProvider.TextNorm)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("PhotosOnboardingView.headline")
                        ForEach(data.rows) { row in
                            PhotosOnboardingRowView(row: row)
                        }
                    }
                    .padding(.horizontal, 52)
                }
            }
            .padding(.vertical, 24)
            Spacer()
            BlueRectButton(title: data.button, cornerRadius: .huge, action: viewModel.enableBackup)
                .accessibilityIdentifier("PhotosOnboardingView.enableBackupButton")
                .padding(24)
        }
        .background(ColorProvider.BackgroundNorm)
    }

    private func makeOldContent(with data: PhotosOnboardingViewData) -> some View {
        VStack(alignment: .center) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 0) {
                        Spacer(minLength: 0)
                        InternalIcon.photosOnboardingOld
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Text(data.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ColorProvider.TextNorm)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("PhotosOnboardingView.headline")
                        ForEach(data.rows) { row in
                            PhotosOnboardingRowView(row: row)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 24)
            Spacer()
            BlueRectButton(title: data.button, cornerRadius: .huge, action: viewModel.enableBackup)
                .accessibilityIdentifier("PhotosOnboardingView.enableBackupButton")
                .padding(24)
        }
        .background(ColorProvider.BackgroundNorm)
    }
}
