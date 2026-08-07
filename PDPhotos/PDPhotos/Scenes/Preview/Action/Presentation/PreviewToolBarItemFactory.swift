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
        let pool: [PhotosAction]
        switch source {
        case .photoStream:
            pool = makeItemsForPhotoStream(isFavorited: isFavorited)
        case .album(let role):
            pool = makeItemsForAlbum(role: role, isFavorited: isFavorited, hasSaveSharedPhoto: hasSaveSharedPhoto)
        case .undetermined:
            return .init(primary: [], more: nil)
        }
        return splitSorted(pool)
    }
}

extension PreviewToolBarItemFactory {
    private func makeItemsForPhotoStream(isFavorited: Bool) -> [PhotosAction] {
        return [
            makeShareItem(),
            isFavorited ? .unFavorite : .favorite,
            .createAlbum,
            .availableOffline,
            .info,
            .trash
        ]
    }

    private func makeItemsForAlbum(role: Role, isFavorited: Bool, hasSaveSharedPhoto: Bool) -> [PhotosAction] {
        var actions = [PhotosAction]()

        actions.append(isFavorited ? .unFavorite : .favorite)

        if role.canAdministrate {
            actions.append(.setAsAlbumCover)
        }

        // Album sharing is owner-only: admin sharing is not supported by the backend for photos/albums.
        if role == .owner {
            actions.append(makeShareItem())
        }

        if role.canAdministrate || role == .editor {
            actions.append(.removeFromAlbum)
        }

        if hasSaveSharedPhoto {
            actions.append(.save)
        }

        actions.append(contentsOf: [.shareNative, .availableOffline, .info])
        return actions
    }

    private func splitSorted(_ pool: [PhotosAction]) -> PhotosActions {
        let sorted = pool.sorted { $0.rawValue < $1.rawValue }
        guard sorted.count > 4 else {
            return PhotosActions(primary: sorted, more: nil)
        }

        let destructive = sorted.first { $0 == .trash || $0 == .removeFromAlbum }
        let nonDestructive = sorted.filter { $0 != .trash && $0 != .removeFromAlbum }

        let primary: [PhotosAction]
        if let destructive {
            primary = Array(nonDestructive.prefix(3)) + [destructive]
        } else {
            primary = Array(sorted.prefix(4))
        }

        let primarySet = Set(primary)
        let more = sorted.filter { !primarySet.contains($0) }
        return PhotosActions(primary: primary, more: more.isEmpty ? nil : more)
    }

    private func makeShareItem() -> PhotosAction {
        if featuresController.hasSharing {
            return .newShare
        } else {
            return .share
        }
    }
}
