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
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations

struct MigrationBannerView<ViewModel: PhotosMigrationBannerViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        viewModel.data.map(makeContent)
    }

    private func makeContent(data: PhotosMigrationBannerData) -> some View {
        VStack(spacing: 10) {
            makeTopBanner(with: data)
            makeBottomBanner(with: data)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func makeTopBanner(with data: PhotosMigrationBannerData) -> some View {
        ZStack(alignment: .center) {
            Color.BackgroundSecondary
            HStack(spacing: 8) {
                makeTitle(with: data)
                Spacer(minLength: 0)
                makeButton(with: data.button)
            }
            .padding(12)
        }
        .frame(minHeight: 46)
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(.huge)
    }

    private func makeBottomBanner(with data: PhotosMigrationBannerData) -> some View {
        ZStack(alignment: .leading) {
            Color.BackgroundSecondary
            makeText(string: data.description)
                .padding(12)
        }
        .frame(minHeight: 46)
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(.huge)
    }

    private func makeButton(with text: String) -> some View {
        Button(action: {
            viewModel.start()
        }, label: {
            Text(text)
                .foregroundColor(ColorProvider.TextAccent)
                .font(.body.bold())
                .frame(minWidth: 54)
        })
        .accessibilityIdentifier("MigrationBannerView.startButton")
        .buttonStyle(PlainButtonStyle())
    }

    private func makeTitle(with data: PhotosMigrationBannerData) -> some View {
        HStack(spacing: 8) {
            IconProvider.cloud
                .renderingMode(.template)
                .foregroundColor(ColorProvider.IconWeak)
                .accessibilityIdentifier("MigrationBannerView.icon")
            makeText(string: data.title)
        }
    }

    private func makeText(string: String) -> some View {
        Text(string)
            .foregroundColor(ColorProvider.TextNorm)
            .font(.subheadline)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
    }
}
