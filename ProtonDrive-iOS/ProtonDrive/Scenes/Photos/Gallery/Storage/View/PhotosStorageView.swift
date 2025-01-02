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

import SwiftUI
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations

struct PhotosStorageView<ViewModel: PhotosStorageViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        viewModel.data.map(makeContent)
    }

    private func makeContent(with data: PhotosStorageViewData) -> some View {
        ZStack(alignment: .center) {
            Color.BackgroundSecondary
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 16) {
                    makeTopRow(with: data)
                    data.text.map(makeText)
                }
                makeButtons(with: data)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(.huge)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func makeTopRow(with data: PhotosStorageViewData) -> some View {
        HStack(spacing: 6) {
            WarningBadgeView(severance: data.severance)
                .frame(width: 20, height: 20)
            Text(makeString(text: data.title, color: ColorProvider.TextNorm))
                .accessibilityIdentifier(data.accessibilityIdentifier)
            Spacer()
            makeRightText(with: data)
        }
    }

    private func makeString(text: String, color: Color) -> AttributedString {
        var string = (try? AttributedString(markdown: text)) ?? .init()
        string.font = .body
        string.foregroundColor = color
        return string
    }

    @ViewBuilder
    private func makeRightText(with data: PhotosStorageViewData) -> some View {
        if let items = data.items {
            Text(makeString(text: items, color: ColorProvider.NotificationError))
        }
    }

    private func makeText(with string: String) -> some View {
        Text(string)
            .font(.body)
            .foregroundColor(ColorProvider.TextNorm)
    }

    private func makeButtons(with data: PhotosStorageViewData) -> some View {
        HStack(spacing: 16) {
            Spacer()
            data.closeButton.map { TextButton(title: $0, variant: .contained, action: viewModel.close) }
                .accessibilityIdentifier("StorageView.close.button")
            makeDataButton(with: data)
                .accessibilityIdentifier("StorageView.upgrade.button")
        }
    }

    private func makeDataButton(with data: PhotosStorageViewData) -> some View {
        #if HAS_PAYMENTS
        BlueRectButton(title: data.storageButton, cornerRadius: .huge, action: viewModel.openStorageOptions)
            .fixedSize()
        #else
        BlueRectButton(title: data.storageButton, cornerRadius: .huge, action: {})
            .fixedSize()
            .environment(\.isEnabled, false)
        #endif
    }
}
