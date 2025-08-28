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
import PDUIComponents
import ProtonCoreUIFoundations

struct PhotosPreviewActionView<ViewModel: PhotosPreviewActionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @State private var idealHeight: CGFloat = 0

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ActionBar(
            onSelection: { model in
                makeAction(from: model).map(viewModel.handle(action:))
            },
            items: viewModel.actions.primary.map(makeItem),
            isContainedInVStack: true, // Prevents content hugging
            contextMenu: { model in
                contextMenuView(model: model)
            }
        )
        .padding(.bottom, 20)
        .dialogSheet(item: $viewModel.currentAction, model: viewModel.dialogModel)
        .safeAreaInset(edge: .bottom) {
            ColorProvider.BackgroundNorm
        }
        .ignoresSafeArea()
        .background(ColorProvider.BackgroundNorm)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            NotificationCenter.default.post(name: .actionBarVisibilityIsChanged, object: nil, userInfo: ["isVisible": true])
        }
        .onDisappear {
            NotificationCenter.default.post(name: .actionBarVisibilityIsChanged, object: nil, userInfo: ["isVisible": false])
        }
    }

    private func makeItem(from action: PhotosAction) -> ActionBarButtonViewModel {
        switch action {
        case .trash:
            return .trashMultiple
        case .share:
            return .share
        case .newShare:
            return .newShare
        case .shareNative:
            return .shareNative
        case .availableOffline:
            return .offlineAvailableMultiple
        case .info:
            return .info
        case .toggleFavorite:
            return .toggleFavorite
        case .favorite:
            return .favorite
        case .unFavorite:
            return .unFavorite
        case .more:
            return .more
        case .setAsAlbumCover:
            return .setAsAlbumCover
        case .createAlbum:
            return .createAlbum
        case .shareMultiple:
            return .shareMultiple
        case .save:
            return .save
        }
    }

    private func makeAction(from viewModel: ActionBarButtonViewModel?) -> PhotosAction? {
        switch viewModel {
        case .trashMultiple:
            return .trash
        case .share:
            return .share
        case .shareNative:
            return .shareNative
        case .offlineAvailableMultiple:
            return .availableOffline
        case .newShare:
            return .share
        case .info:
            return .info
        case .setAsAlbumCover:
            return .setAsAlbumCover
        case .toggleFavorite:
            return .toggleFavorite
        case .favorite:
            return .favorite
        case .unFavorite:
            return .unFavorite
        case .createAlbum:
            return .createAlbum
        case .shareMultiple:
            return .shareMultiple
        case .save:
            return .save
        default:
            return nil
        }
    }

    @ViewBuilder
    private func contextMenuView(model: ActionBarButtonViewModel) -> some View {
        if model == .more, let moreItems = viewModel.actions.more {
            let items: [ActionBarButtonViewModel] = moreItems.map(makeItem)
            ForEach(items) { item in
                Button {
                    makeAction(from: item).map(viewModel.handle(action:))
                } label: {
                    HStack {
                        item.icon!
                            .resizable()
                            .frame(width: 20, height: 20, alignment: .top)
                            .foregroundColor(ColorProvider.IconNorm)
                        Text(item.title!)
                            .font(.body)
                            .foregroundColor(ColorProvider.BrandNorm)
                    }
                }
                .accessibilityIdentifier("ContextMenuItemActionView.\(item.accessibilityIdentifier)")
            }
        } else {
            EmptyView()
        }
    }
}
