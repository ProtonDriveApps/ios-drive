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

protocol PhotosListAnchorCache {
    func store(anchor: PhotosListFetchingAnchor, key: PhotosListAnchorKey)
    func load(for key: PhotosListAnchorKey) -> PhotosListFetchingAnchor?
    func remove(for key: PhotosListAnchorKey)
}

final class PersistentPhotosListAnchorCache: PhotosListAnchorCache {
    typealias AnchorsDictionary = [PhotosListAnchorKey: PhotosListFetchingAnchor]
    private static let delimiter = "@"

    @SettingsCodableProperty(SettingsStorageKey.photosListAnchorsCacheKey.value) private var persistentCache: AnchorsDictionary = [:]
    private var inMemoryCache = AnchorsDictionary()
    private let queue = DispatchQueue(label: "PhotosListAnchorCache", qos: .userInteractive, attributes: .concurrent)
    private var isInitialized: Bool = false

    init() {
        // Intentionally using standard, so it's cleaned up during sign out / clear cache
        _persistentCache.configure(with: .standard)
    }

    func store(anchor: PhotosListFetchingAnchor, key: PhotosListAnchorKey) {
        inMemoryCache[key] = anchor
        queue.async(flags: .barrier) { [weak self] in
            self?.persistentCache[key] = anchor
        }
    }

    func load(for key: PhotosListAnchorKey) -> PhotosListFetchingAnchor? {
        initializeIfNeeded()
        return inMemoryCache[key]
    }

    func remove(for key: PhotosListAnchorKey) {
        inMemoryCache[key] = nil
        queue.async(flags: .barrier) { [weak self] in
            self?.persistentCache[key] = nil
        }
    }

    private func initializeIfNeeded() {
        // Called lazily once. But not in init!
        if !isInitialized {
            inMemoryCache = persistentCache
            isInitialized = true
        }
    }
}
