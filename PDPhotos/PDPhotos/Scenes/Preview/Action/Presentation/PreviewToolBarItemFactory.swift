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

import Foundation
import PDCore
import PDCoreIOS

struct PreviewToolBarItemFactory {
    private let streamConfiguration: PhotoStreamConfiguration
    private let featuresController: FeatureFlagsControllerProtocol

    init(streamConfiguration: PhotoStreamConfiguration, featuresController: FeatureFlagsControllerProtocol) {
        self.streamConfiguration = streamConfiguration
        self.featuresController = featuresController
    }

    func makeItems(for source: PhotosPreviewSource, isFavorited: Bool, hasSaveSharedPhoto: Bool) -> PhotosActions {
        var actions = [PhotosAction]()
        switch source {
        case .photoStream:
            actions = makeItemsForPhotoStream(isFavorited: isFavorited)
        case .album(let role):
            actions = makeItemsForAlbum(isAdmin: role == .admin, isEditor: role == .editor, isFavorited: isFavorited, hasSaveSharedPhoto: hasSaveSharedPhoto)
        case .undetermined:
            return .init(primary: [], more: [])
        }
        let sortedActions = actions.sorted { $0.rawValue < $1.rawValue }
        if sortedActions.count > 4 {
            let primaryActions = Array(sortedActions.prefix(3)) + [.more]
            let moreActions = Array(sortedActions.dropFirst(3))
            return PhotosActions(primary: primaryActions, more: moreActions)
        } else {
            return PhotosActions(primary: sortedActions, more: nil)
        }
    }
}

extension PreviewToolBarItemFactory {
    private func makeItemsForPhotoStream(isFavorited: Bool) -> [PhotosAction] {
        var actions = [PhotosAction]()
        actions.append(makeShareItem())
        if arePhotoVolumeActionsAllowed() {
            actions.append(isFavorited ? .unFavorite : .favorite)
            actions.append(.createAlbum)
        }
        actions.append(contentsOf: [.availableOffline, .info, .trash])
        return actions
    }

    private func makeItemsForAlbum(isAdmin: Bool, isEditor: Bool, isFavorited: Bool, hasSaveSharedPhoto: Bool) -> [PhotosAction] {
        var actions = [PhotosAction]()

        if arePhotoVolumeActionsAllowed() {
            actions.append(isFavorited ? .unFavorite : .favorite)
        }

        if isAdmin {
            actions.append(.setAsAlbumCover)
            actions.append(makeShareItem())
        }

        if isAdmin || isEditor {
            actions.append(.trash)
        }

        if hasSaveSharedPhoto {
            actions.append(.save)
        }

        actions.append(contentsOf: [.shareNative, .availableOffline, .info])
        return actions
    }

    private func makeShareItem() -> PhotosAction {
        if featuresController.hasAlbumsSharing {
            return .newShare
        } else {
            return .share
        }
    }

    private func arePhotoVolumeActionsAllowed() -> Bool {
        featuresController.hasAlbumsActions && !streamConfiguration.isLegacyShare
    }
}
