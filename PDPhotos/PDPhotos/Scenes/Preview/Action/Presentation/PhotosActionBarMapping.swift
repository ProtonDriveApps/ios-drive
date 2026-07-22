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

import PDUIComponents
import ProtonCoreUIFoundations
import UIKit

enum PhotosActionBarMapping {
    static func buttonViewModel(for action: PhotosAction) -> ActionBarButtonViewModel {
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
        case .removeFromAlbum:
            return .removeFromAlbum
        }
    }

    static func photosAction(for viewModel: ActionBarButtonViewModel?) -> PhotosAction? {
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
            return .newShare
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
        case .removeFromAlbum:
            return .removeFromAlbum
        default:
            return nil
        }
    }

    static func makeUIActions(from actions: [PhotosAction], handler: @escaping (PhotosAction) -> Void) -> [UIAction] {
        actions.map { action in
            let viewModel = buttonViewModel(for: action)
            let uiAction = UIAction(
                title: menuTitle(for: viewModel),
                image: uiImage(for: viewModel),
                attributes: viewModel.isDestructive ? .destructive : []
            ) { _ in
                handler(action)
            }
            uiAction.accessibilityIdentifier = "ContextMenuItemActionView.\(viewModel.accessibilityIdentifier)"
            return uiAction
        }
    }

    private static func menuTitle(for viewModel: ActionBarButtonViewModel) -> String {
        viewModel.title ?? ""
    }

    private static func uiImage(for viewModel: ActionBarButtonViewModel) -> UIImage? {
        switch viewModel {
        case .trashMultiple, .removeFromAlbum:
            return IconProvider.trash
        case .moveMultiple:
            return IconProvider.folderArrowIn
        case .offlineAvailableMultiple:
            return IconProvider.arrowDownCircle
        case .share:
            return IconProvider.link
        case .shareNative, .shareMultiple:
            return IconProvider.arrowUpFromSquare
        case .newShare:
            return IconProvider.userPlus
        case .info:
            return IconProvider.infoCircle
        case .toggleFavorite, .favorite:
            return IconProvider.heart
        case .unFavorite:
            return UIImage(named: "ic-heart-filled", in: .module, with: nil)
        case .more:
            return IconProvider.threeDotsHorizontal
        case .setAsAlbumCover:
            return IconProvider.windowImage
        case .createAlbum:
            return IconProvider.plus
        case .save:
            return UIImage(named: "ic-cloud-arrow-down", in: .module, with: nil)
        default:
            return nil
        }
    }
}
