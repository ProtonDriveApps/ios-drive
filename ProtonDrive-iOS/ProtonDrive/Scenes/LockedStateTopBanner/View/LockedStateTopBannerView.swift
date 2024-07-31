// Copyright (c) 2024 Proton AG
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
import Combine
import PDUIComponents
import ProtonCoreUIFoundations

struct LockedStateTopBannerView: View {
    @ObservedObject private var viewModel: LockedStateTopBannerViewModel

    init(viewModel: LockedStateTopBannerViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        makeContent(with: viewModel.data)
    }

    private func makeContent(with data: LockedStateTopBannerViewData) -> some View {
        ZStack(alignment: .center) {
            Color.BackgroundSecondary
            VStack(alignment: .leading, spacing: 16) {
                makeTopRow(with: data)
                if let description = data.description {
                    makeText(with: description)
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

    private func makeTopRow(with data: LockedStateTopBannerViewData) -> some View {
        HStack(spacing: 6) {
            WarningBadgeView(severance: data.severance)
                .frame(width: 20, height: 20)
            if let title = data.title {
                Text(makeString(text: title, color: ColorProvider.TextNorm))
            }
        }
    }

    private func makeString(text: String, color: Color) -> AttributedString {
        var string = (try? AttributedString(markdown: text)) ?? .init()
        string.font = .body
        string.foregroundColor = color
        return string
    }

    private func makeText(with string: String) -> some View {
        Text(string)
            .font(.body)
            .foregroundColor(ColorProvider.TextNorm)
    }

    private func makeButtons(with data: LockedStateTopBannerViewData) -> some View {
        HStack {
            Spacer()
            if let buttonTitle = data.actionButton {
                makeActionButton(with: buttonTitle)
            }
        }
    }

    private func makeActionButton(with buttonTitle: String) -> some View {
        BlueRectButton(title: buttonTitle, height: 36, cornerRadius: .huge, action: viewModel.openUrl)
            .fixedSize()
    }
}
