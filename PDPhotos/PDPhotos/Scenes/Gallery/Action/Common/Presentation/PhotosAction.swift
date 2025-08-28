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

enum PhotosAction: Int, Identifiable {
    var id: String {
        "\(self)"
    }

    // Ordered by priority - will be displayed in order below
    /// Legacy share, only have public link option/
    case share
    /// When album is disabled: Share with public link or specific users
    /// When album is enabled: `ShareToActionSheet`
    case newShare
    /// Share multiple selections, create shared album or add to existed albums/
    case shareMultiple
    case toggleFavorite
    case favorite
    case unFavorite
    case save
    case createAlbum
    case shareNative // iOS system share activity
    case availableOffline
    case info
    case setAsAlbumCover
    case trash
    case more
}

struct PhotosActions: Equatable {
    let primary: [PhotosAction]
    let more: [PhotosAction]?
}
