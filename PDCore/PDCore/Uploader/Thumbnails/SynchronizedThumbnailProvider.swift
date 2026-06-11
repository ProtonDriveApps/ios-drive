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

public protocol SynchronizedThumbnailProviderProtocol {
    func defaultThumbnailData(fileUrl: URL, overrideMediaType: String?) async -> Data?
    func photoThumbnailData(fileUrl: URL, overrideMediaType: String?) async -> Data?
}

/// CGImageSourceCreateThumbnailAtIndex invokes semaphore_wait could cause deadlock
/// This actor make sure we generate one thumbnail at a time to prevent deadlock
public actor SynchronizedThumbnailProvider: SynchronizedThumbnailProviderProtocol {
    private let thumbnailProvider: ThumbnailProvider

    public init(thumbnailProvider: ThumbnailProvider) {
        self.thumbnailProvider = thumbnailProvider
    }

    public func defaultThumbnailData(fileUrl: URL, overrideMediaType: String? = nil) -> Data? {
        thumbnailProvider.defaultThumbnailData(
            fileUrl: fileUrl,
            overrideMediaType: overrideMediaType,
            ofSize: ThumbnailSize.default.value
        )
    }

    public func photoThumbnailData(fileUrl: URL, overrideMediaType: String?) -> Data? {
        thumbnailProvider.defaultThumbnailData(
            fileUrl: fileUrl,
            overrideMediaType: overrideMediaType,
            ofSize: ThumbnailSize.photo.value
        )
    }
}

private enum ThumbnailSize {
    case `default`
    case photo

    var value: CGSize {
        switch self {
        case .default:
            return Constants.defaultThumbnailMaxSize
        case .photo:
            return Constants.photoThumbnailMaxSize
        }
    }
}
