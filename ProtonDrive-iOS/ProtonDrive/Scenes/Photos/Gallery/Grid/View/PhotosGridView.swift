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
import ProtonCore_UIFoundations

struct PhotosGridView<ViewModel: PhotosGridViewModelProtocol, ItemView: View>: View {
    @ObservedObject private var viewModel: ViewModel
    private let item: (PhotoGridViewItem) -> ItemView
    private let spacing: CGFloat = 1.5

    init(viewModel: ViewModel, item: @escaping (PhotoGridViewItem) -> ItemView) {
        self.viewModel = viewModel
        self.item = item
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(viewModel.sections) {
                        view(from: $0, height: (geometry.size.width / 3) * 1.4)
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: .init(.flexible(), spacing: spacing), count: 3)
    }

    private func view(from section: PhotosGridViewSection, height: CGFloat) -> some View {
        Section(content: {
            ForEach(section.items) {
                item($0)
                    .frame(height: height)
            }
        }, header: {
            Text(section.title)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(ColorProvider.TextWeak)
                .padding(EdgeInsets(top: 24, leading: 16, bottom: 8, trailing: 16))
        })
    }
}
