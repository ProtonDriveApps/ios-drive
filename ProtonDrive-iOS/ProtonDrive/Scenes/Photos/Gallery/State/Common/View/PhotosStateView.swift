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

import ProtonCore_UIFoundations
import SwiftUI

struct PhotosStateView<ViewModel: PhotosStateViewModelProtocol, TitleView: View>: View {
    @ObservedObject private var viewModel: ViewModel
    private let title: ([PhotosStateTitle]) -> TitleView

    init(viewModel: ViewModel, title: @escaping ([PhotosStateTitle]) -> TitleView) {
        self.viewModel = viewModel
        self.title = title
    }

    var body: some View {
        if let data = viewModel.viewData {
            makeBody(with: data)
        } else {
            EmptyView()
        }
    }

    private func makeBody(with data: PhotosStateViewData) -> some View {
        ZStack(alignment: .center) {
            Color.BackgroundSecondary
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    title(data.titles)
                    Spacer()
                    data.rightText.map(makeRightText)
                }
                data.progress.map(makeProgress)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
        }
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(.huge)
        .padding(16)
    }

    private func makeRightText(with text: String) -> some View {
        Text(text)
            .foregroundColor(ColorProvider.TextAccent)
            .font(.body.bold())
    }

    private func makeProgress(with progress: Float) -> some View {
        GeometryReader { geometry in
            ColorProvider.InteractionWeak
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    ColorProvider.InteractionNorm
                        .frame(width: geometry.size.width * CGFloat(progress))
                }
                .cornerRadius(.medium)
        }
    }
}
