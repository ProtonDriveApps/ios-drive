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

import CoreImage

public protocol ThumbnailProvider: AnyObject {
    typealias Image = CGImage

    var next: ThumbnailProvider? { get set }

    /// Generates thumbnail for file at given URL.
    /// - Parameters:
    ///   - url: URL to media
    ///   - overrideMediaType: allows callers to provide a mediaType for files not matching conventional
    ///   file names and extensions.
    ///   - size: size for the expected thumbnail.
    /// - Returns: an Image if the process was successful.
    func getThumbnail(
        from url: URL,
        overrideMediaType: String?,
        ofSize size: CGSize
    ) -> Image?
}

public enum ThumbnailProviderFactory {
    public static var defaultSynchronizedThumbnailProvider: SynchronizedThumbnailProviderProtocol {
        return SynchronizedThumbnailProvider(thumbnailProvider: defaultThumbnailProvider)
    }

    public static var defaultThumbnailProvider: ThumbnailProvider {
        CGImageThumbnailProvider(next: PDFThumbnailProvider(next: VideoThumbnailProvider()))
    }

    public static var imageVideoThumbnailProvider: ThumbnailProvider {
        return CGImageThumbnailProvider(next: VideoThumbnailProvider())
    }

    public static var SynchedImageVideoThumbnailProvider: SynchronizedThumbnailProviderProtocol {
        return SynchronizedThumbnailProvider(thumbnailProvider: imageVideoThumbnailProvider)
    }
}

public final class NoopThumbnailProvider: ThumbnailProvider {
    public static let instance: NoopThumbnailProvider = .init()
    public var next: ThumbnailProvider? { get { nil } set { _ = newValue } }
    public func getThumbnail(from url: URL, overrideMediaType: String?, ofSize size: CGSize) -> Image? { nil }
}
