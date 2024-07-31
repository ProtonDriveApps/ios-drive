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
import ProtonCoreUIFoundations
import PDUIComponents

struct PhotosGridView<ViewModel: PhotosGridViewModelProtocol, ActionView: View, ItemView: View>: View {
    @ObservedObject private var viewModel: ViewModel
    private let actionView: ActionView
    private let item: (PhotoGridViewItem, String) -> ItemView
    
    private let itemAspectRatio: CGFloat = 1 / 1.4
    private let minimumNumberOfColumns: CGFloat = 3
    private let preferableItemWidth: CGFloat = 128
    private let spacing: CGFloat = 1.5

    init(viewModel: ViewModel, actionView: ActionView, item: @escaping (PhotoGridViewItem, String) -> ItemView) {
        self.viewModel = viewModel
        self.actionView = actionView
        self.item = item
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columns(width: geometry.size.width), alignment: .leading, spacing: spacing) {
                    ForEach(viewModel.sections) {
                        view(from: $0)
                    }
                }
                Spacer(minLength: 32)
                LazyVGrid(columns: [.init()]) {
                    bottomView
                        .modifier(StretchModifier(containerFrame: geometry.frame(in: .global)))
                }
                .padding(.bottom, ActionBarSize.height)
            }
        }
        .errorToast(location: .bottom, errors: viewModel.error)
        .overlay {
            actionView
        }
    }

    private func columns(width: CGFloat) -> [GridItem] {
        let widthForExtraColumns = preferableItemWidth * (minimumNumberOfColumns + 1) + spacing * (minimumNumberOfColumns - 1)
        if width >= widthForExtraColumns {
            return [GridItem(.adaptive(minimum: preferableItemWidth, maximum: .infinity))]
        } else {
            return Array(repeating: .init(.flexible(), spacing: spacing), count: 3)
        }
    }

    private func view(from section: PhotosGridViewSection) -> some View {
        Section(content: {
            ForEach(Array(section.items.enumerated()), id: \.element.id) {
                item($0.element, "\(section.title)_\($0.offset)")
                    .aspectRatio(itemAspectRatio, contentMode: .fit)
            }
        }, header: {
            Text(section.title)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(ColorProvider.TextWeak)
                .padding(EdgeInsets(top: section.isFirst ? 14 : 24, leading: 16, bottom: 8, trailing: 16))
        })
    }

    private var bottomView: some View {
        HStack(alignment: .center, spacing: 6) {
            Spacer()
            IconProvider.lockCheckFilled
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(ColorProvider.IconWeak)
            Text(viewModel.footer)
                .font(.caption)
                .foregroundColor(ColorProvider.TextWeak)
            Spacer()
        }
        .padding(.bottom, 16)
        .onAppear(perform: viewModel.didShowLastItem)
    }
}
