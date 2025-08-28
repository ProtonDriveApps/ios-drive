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

import Foundation
import PDCore

struct PhotosGridViewSection: Identifiable {
    var id: String {
        title
    }

    let title: String
    let isFirst: Bool
    let items: [PhotoGridViewItem]
}

struct PhotoGridViewItem: Identifiable, Hashable, GridViewItem {
    var id: AnyVolumeIdentifier {
        .init(id: photoId, volumeID: volumeId)
    }

    let photoId: String // primary photo id
    let secondaryIds: [String] // secondary photo ids
    let volumeId: String
    let albumId: String?
    let captureTime: Date
    let metadata: Metadata?

    struct Metadata: Hashable {
        let isShared: Bool
        let hasDirectShare: Bool
        let isVideo: Bool
        let isDownloading: Bool
        let isAvailableOffline: Bool
        let burstChildrenCount: Int?
        let isFavorite: Bool
    }
}
