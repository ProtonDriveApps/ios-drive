// Copyright (c) 2026 Proton AG
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

/// Memoizes the sha256-derived thumbnail locations for a photo, so repeated reads while scrolling
/// don't recompute the checksum. A single instance is shared by all item view models of a grid
/// scene. Assumes main thread.
public protocol ThumbnailURLCache {
    func getThumbnailData(id: AnyVolumeIdentifier) -> Data?
}

final class SmallThumbnailURLCache: ThumbnailURLCache {
    private static let maxEntries = 40_000
    private var urlsCache = [AnyVolumeIdentifier: [URL]]()

    func getThumbnailData(id: AnyVolumeIdentifier) -> Data? {
        assert(Thread.isMainThread, "ThumbnailURLCache must be used on the main thread")
        if let url = getURLs(for: id).first(where: { url in
            FileManager.default.fileExists(atPath: url.path)
        }) {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    private func getURLs(for id: AnyVolumeIdentifier) -> [URL] {
        if let cached = urlsCache[id] {
            return cached
        }
        if urlsCache.count >= Self.maxEntries {
            urlsCache.removeAll(keepingCapacity: true)
        }
        let urls = PDFileManager.getPossibleThumbnailURLs(for: id.volumeBasedIdentifier, type: .default)
        urlsCache[id] = urls
        return urls
    }
}
