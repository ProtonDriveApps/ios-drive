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
import PDLocalization

final class AlbumGalleryPlaceholderViewModel {
    private let currentTag: AlbumUITag

    init(currentTag: AlbumUITag) {
        self.currentTag = currentTag
    }

    var shouldShowCreateButton: Bool {
        currentTag != .existing(.sharedWithMe)
    }

    var createAlbumActionTitle: String {
        Localization.empty_albums_action
    }

    var placeholderTitle: String {
        switch currentTag {
        case .all:
            return Localization.empty_albums_title
        case .existing(let tag):
            switch tag {
            case .myAlbums:
                return Localization.empty_albums_title
            case .shared:
                return Localization.empty_shared_album_title
            case .sharedWithMe:
                return Localization.empty_shared_with_me_albums_title
            }
        }
    }

    var placeholderMessage: String {
        switch currentTag {
        case .all:
            return Localization.empty_albums_message
        case .existing(let tag):
            switch tag {
            case .myAlbums:
                return Localization.empty_my_albums_message
            case .shared:
                return Localization.empty_shared_album_message
            case .sharedWithMe:
                return Localization.empty_shared_with_me_albums_message
            }
        }
    }
}
