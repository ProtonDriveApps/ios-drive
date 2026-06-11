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

import CoreServices
import CoreImage

final class CGImageThumbnailProvider: ThumbnailProvider {

    var next: ThumbnailProvider?
    
    init(next: ThumbnailProvider? = nil) {
        self.next = next
    }

    func getThumbnail(from url: URL, overrideMediaType: String?, ofSize size: CGSize) -> Image? {
        let mimeType = overrideMediaType.flatMap { MimeType(value: $0) } ?? MimeType(fromFileExtension: url.pathExtension)

        guard mimeType?.isImage == true else {
            return next?.getThumbnail(from: url, overrideMediaType: overrideMediaType, ofSize: size)
        }

        #if os(iOS)
        if Constants.runningInExtension,
           let fileSize = try? url.getFileSize(),
           fileSize > 22 * 1024 * 1024 {
            // Image larger than 22 MB is easy to exceed memory limitation
            return next?.getThumbnail(from: url, overrideMediaType: overrideMediaType, ofSize: size)
        }
        #endif

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size.height
        ]

        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        return cgImage
    }
}
