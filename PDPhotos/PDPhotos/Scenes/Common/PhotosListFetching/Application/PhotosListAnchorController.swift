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

import PDCore

struct PhotosListAnchorIdentifier {
    let configuration: PhotosListConfiguration
    let filter: PhotosListFilter?
}

struct PhotosListAnchorKey: Hashable, Codable {
    let volumeId: String
    let albumId: String?
    let tag: PhotoTag?
}

protocol PhotosListAnchorControllerProtocol {
    func load(for identifier: PhotosListAnchorIdentifier) -> PhotosListFetchingAnchor?
    func store(anchor: PhotosListFetchingAnchor, for identifier: PhotosListAnchorIdentifier)
    func remove(for identifier: PhotosListAnchorIdentifier)
}

final class PhotosListAnchorController: PhotosListAnchorControllerProtocol {
    private let cache: PhotosListAnchorCache

    init(cache: PhotosListAnchorCache) {
        self.cache = cache
    }

    func load(for identifier: PhotosListAnchorIdentifier) -> PhotosListFetchingAnchor? {
        Log.debug("load anchor for identifier: \(identifier)", domain: .photosUI)
        let key = makeKey(from: identifier)
        return cache.load(for: key)
    }

    func store(anchor: PhotosListFetchingAnchor, for identifier: PhotosListAnchorIdentifier) {
        Log.debug("store anchor for identifier: \(identifier), anchor: \(anchor)", domain: .photosUI)
        let key = makeKey(from: identifier)
        cache.store(anchor: anchor, key: key)
    }

    func remove(for identifier: PhotosListAnchorIdentifier) {
        Log.debug("remove anchor for identifier: \(identifier)", domain: .photosUI)
        let key = makeKey(from: identifier)
        cache.remove(for: key)
    }

    private func makeKey(from identifier: PhotosListAnchorIdentifier) -> PhotosListAnchorKey {
        PhotosListAnchorKey(
            volumeId: identifier.configuration.volumeId,
            albumId: identifier.configuration.albumId,
            tag: identifier.filter?.tag
        )
    }
}
